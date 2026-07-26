import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sing_list/ai/ai_exception.dart';
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
}
