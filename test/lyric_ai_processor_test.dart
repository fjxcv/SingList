import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sing_list/ai/ai_exception.dart';
import 'package:sing_list/ai/ai_provider_config.dart';
import 'package:sing_list/ai/openai_compatible_client.dart';
import 'package:sing_list/lyrics/lyric_ai_processor.dart';

void main() {
  final processor = LyricAiProcessor(OpenAiCompatibleClient());

  String response(List<Map<String, dynamic>> lines,
      {String language = 'ja', List<String> warnings = const []}) {
    return jsonEncode({
      'language': language,
      'lines': lines,
      'warnings': warnings,
    });
  }

  Map<String, dynamic> line(
    int index,
    String original,
    String display,
    String translation,
  ) =>
      {
        'index': index,
        'original': original,
        'display': display,
        'translation': translation,
      };

  const config = AiProviderConfig(
    provider: AiProvider.custom,
    baseUrl: 'https://example.com/v1',
    model: 'test-model',
    timeoutSeconds: 60,
    enabled: true,
  );

  http.Response blockResponse(http.Request request) {
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    final messages = body['messages'] as List<dynamic>;
    final prompt = (messages.last as Map<String, dynamic>)['content'] as String;
    final matches =
        RegExp(r'^(\d+): (.*)$', multiLine: true).allMatches(prompt).toList();
    return http.Response(
      jsonEncode({
        'model': 'test-model',
        'language': 'en',
        'choices': [
          {
            'message': {
              'content': jsonEncode({
                'language': 'en',
                'lines': [
                  for (final match in matches)
                    {
                      'index': int.parse(match.group(1)!),
                      'display': match.group(2)!,
                      'translation': '译${match.group(2)!}',
                    },
                ],
                'warnings': <String>[],
              }),
            },
          },
        ],
      }),
      200,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  }

  String blockPrompt(http.Request request) {
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    final messages = body['messages'] as List<dynamic>;
    return (messages.last as Map<String, dynamic>)['content'] as String;
  }

  test('accepts Japanese furigana, warnings and Markdown JSON fence', () {
    final json = response(
      [line(0, '空', '[空|そら]', '天空')],
      warnings: ['特殊读音请确认'],
    );
    final result = processor.parseAndValidate(
      '```json\n$json\n```',
      originalLyrics: '空',
      actualModel: 'model',
    );

    expect(result.displayText, '[空|そら]');
    expect(result.translationText, '天空');
    expect(result.warnings, ['特殊读音请确认']);
  });

  test('accepts the compact response without repeating original lyrics', () {
    final result = processor.parseAndValidate(
      jsonEncode({
        'language': 'ja',
        'lines': [
          {
            'index': 0,
            'display': '[空|そら]',
            'translation': '天空',
          },
        ],
        'warnings': <String>[],
      }),
      originalLyrics: '空',
      actualModel: 'model',
    );

    expect(result.originalText, '空');
    expect(result.displayText, '[空|そら]');
  });

  test('uses a longer bounded timeout for long lyrics', () {
    expect(
      LyricAiProcessor.recommendedTimeoutSeconds(
        configuredSeconds: 60,
        rawLyrics: '短い歌詞',
      ),
      60,
    );
    expect(
      LyricAiProcessor.recommendedTimeoutSeconds(
        configuredSeconds: 60,
        rawLyrics: List.filled(500, '長い歌詞').join('\n'),
      ),
      180,
    );
  });

  test('normalizes a slash separator returned by the AI', () {
    final result = processor.parseAndValidate(
      response([
        line(0, '雨が降った', '[雨/あめ]が[降/ふ]った', '下雨了'),
      ]),
      originalLyrics: '雨が降った',
      actualModel: 'model',
    );

    expect(result.displayText, '[雨|あめ]が[降|ふ]った');
  });

  test('normalizes full-width separators returned by the AI', () {
    final result = processor.parseAndValidate(
      response([
        line(0, '花が散った', '[花｜はな]が[散／ち]った', '花凋谢了'),
      ]),
      originalLyrics: '花が散った',
      actualModel: 'model',
    );

    expect(result.displayText, '[花|はな]が[散|ち]った');
  });

  test('does not rewrite an ambiguous slash inside brackets', () {
    expect(
      () => processor.parseAndValidate(
        response([line(0, 'A/B', '[A/B]', 'A/B')]),
        originalLyrics: 'A/B',
        actualModel: 'model',
      ),
      throwsA(
        isA<AiException>().having(
          (error) => error.message,
          'message',
          contains('注音格式错误'),
        ),
      ),
    );
  });

  test('rejects a blank translation for a non-empty Japanese line', () {
    expect(
      () => processor.parseAndValidate(
        response([line(0, '空', '[空|そら]', '')]),
        originalLyrics: '空',
        actualModel: 'model',
      ),
      throwsA(
        isA<AiException>().having(
          (error) => error.message,
          'message',
          contains('中文翻译'),
        ),
      ),
    );
  });

  test('allows a blank translation for an empty Japanese line', () {
    final result = processor.parseAndValidate(
      response([
        line(0, '空', '[空|そら]', '天空'),
        line(1, '', '', ''),
      ]),
      originalLyrics: '空\n',
      actualModel: 'model',
    );

    expect(result.translationText, '天空\n');
  });

  test('accepts ordinary non-Japanese lyrics', () {
    final result = processor.parseAndValidate(
      response(
        [line(0, 'Hello', 'Hello', '你好')],
        language: 'en',
      ),
      originalLyrics: 'Hello',
      actualModel: 'model',
    );

    expect(result.language, 'en');
    expect(result.displayText, 'Hello');
  });

  test('preserves empty lines and repeated choruses', () {
    final result = processor.parseAndValidate(
      response([
        line(0, 'chorus', 'chorus', '副歌'),
        line(1, '', '', ''),
        line(2, 'chorus', 'chorus', '副歌'),
      ], language: 'en'),
      originalLyrics: 'chorus\n\nchorus',
      actualModel: 'model',
    );

    expect(result.originalText, 'chorus\n\nchorus');
  });

  test('rejects line count mismatch', () {
    expect(
      () => processor.parseAndValidate(
        response([line(0, 'one', 'one', '一')]),
        originalLyrics: 'one\ntwo',
        actualModel: 'model',
      ),
      throwsA(isA<AiException>()),
    );
  });

  test('rejects illegal JSON with a clear error', () {
    expect(
      () => processor.parseAndValidate(
        'not-json',
        originalLyrics: 'line',
        actualModel: 'model',
      ),
      throwsA(
        isA<AiException>().having(
          (error) => error.message,
          'message',
          contains('非法 JSON'),
        ),
      ),
    );
  });

  test('rejects missing or duplicate indexes', () {
    expect(
      () => processor.parseAndValidate(
        response([
          line(0, 'one', 'one', '一'),
          line(0, 'two', 'two', '二'),
        ]),
        originalLyrics: 'one\ntwo',
        actualModel: 'model',
      ),
      throwsA(isA<AiException>()),
    );
  });

  test('rejects malformed furigana', () {
    expect(
      () => processor.parseAndValidate(
        response([line(0, '空', '[空そら]', '天空')]),
        originalLyrics: '空',
        actualModel: 'model',
      ),
      throwsA(isA<AiException>()),
    );
  });

  test('reports validation errors with the global line number', () {
    expect(
      () => processor.parseAndValidate(
        response([line(0, '空', '[空そら]', '天空')]),
        originalLyrics: '空',
        actualModel: 'model',
        lineNumberOffset: 12,
      ),
      throwsA(
        isA<AiException>().having(
          (error) => error.message,
          'message',
          contains('第 13 行'),
        ),
      ),
    );
  });

  test('rejects lyrics changed by the model', () {
    expect(
      () => processor.parseAndValidate(
        response([line(0, 'invented', 'invented', '编造')]),
        originalLyrics: 'original',
        actualModel: 'model',
      ),
      throwsA(isA<AiException>()),
    );
  });

  test('processes 12-line blocks concurrently and merges by original order',
      () async {
    var active = 0;
    var maxActive = 0;
    var requestCount = 0;
    final chunkedProcessor = LyricAiProcessor(
      OpenAiCompatibleClient(
        httpClient: MockClient((request) async {
          requestCount++;
          active++;
          if (active > maxActive) maxActive = active;
          final isFirstBlock = blockPrompt(request).contains('0: 行0\n');
          await Future<void>.delayed(
            Duration(milliseconds: isFirstBlock ? 40 : 5),
          );
          active--;
          return blockResponse(request);
        }),
      ),
    );
    final source = List.generate(25, (index) => '行$index').join('\n');

    final result = await chunkedProcessor.process(
      config: config,
      apiKey: 'key',
      title: 'title',
      artist: 'artist',
      rawLyrics: source,
    );

    expect(requestCount, 3);
    expect(maxActive, inInclusiveRange(2, 3));
    expect(result.originalText, source);
    expect(result.displayText, source);
    expect(
      result.lines.map((item) => item.index),
      orderedEquals(List.generate(25, (index) => index)),
    );
  });

  test('keeps successful blocks when retrying only a failed block', () async {
    var failingBlockCanSucceed = false;
    final calls = <String, int>{};
    final chunkedProcessor = LyricAiProcessor(
      OpenAiCompatibleClient(
        httpClient: MockClient((request) async {
          final prompt = blockPrompt(request);
          final blockKey = prompt.contains('0: 行12\n')
              ? 'middle'
              : prompt.contains('0: 行0\n')
                  ? 'first'
                  : 'last';
          calls[blockKey] = (calls[blockKey] ?? 0) + 1;
          if (blockKey == 'middle' && !failingBlockCanSucceed) {
            return http.Response('temporary error', 500);
          }
          return blockResponse(request);
        }),
      ),
    );
    final source = List.generate(25, (index) => '行$index').join('\n');
    final session = chunkedProcessor.createSession(source);

    await expectLater(
      chunkedProcessor.processSession(
        session: session,
        config: config,
        apiKey: 'key',
        title: 'title',
        artist: 'artist',
      ),
      throwsA(isA<LyricChunkProcessingException>()),
    );
    expect(session.failedBlocks.single.index, 1);
    expect(calls, {'first': 1, 'middle': 2, 'last': 1});

    failingBlockCanSucceed = true;
    final result = await chunkedProcessor.processSession(
      session: session,
      config: config,
      apiKey: 'key',
      title: 'title',
      artist: 'artist',
      retryFailedOnly: true,
    );

    expect(calls, {'first': 1, 'middle': 3, 'last': 1});
    expect(result.originalText, source);
    expect(result.translationText.split('\n'), hasLength(25));
  });

  test('does not treat authentication failures as retryable block errors',
      () async {
    final chunkedProcessor = LyricAiProcessor(
      OpenAiCompatibleClient(
        httpClient: MockClient((_) async => http.Response('unauthorized', 401)),
      ),
    );

    await expectLater(
      chunkedProcessor.process(
        config: config,
        apiKey: 'bad-key',
        title: 'title',
        artist: 'artist',
        rawLyrics: List.generate(20, (index) => '行$index').join('\n'),
      ),
      throwsA(
        isA<AiException>().having(
          (error) => error.kind,
          'kind',
          AiErrorKind.authentication,
        ),
      ),
    );
  });
}
