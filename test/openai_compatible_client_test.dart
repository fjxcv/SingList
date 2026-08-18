import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sing_list/ai/ai_exception.dart';
import 'package:sing_list/ai/ai_provider_config.dart';
import 'package:sing_list/ai/openai_compatible_client.dart';

void main() {
  AiProviderConfig config({
    String baseUrl = 'https://example.com/v1/',
    int timeoutSeconds = 30,
  }) {
    return AiProviderConfig(
      provider: AiProvider.custom,
      baseUrl: baseUrl,
      model: 'test-model',
      timeoutSeconds: timeoutSeconds,
      enabled: true,
    );
  }

  test('normalizes base URL without duplicating endpoint', () {
    expect(
      OpenAiCompatibleClient.chatCompletionsUri(
        'https://example.com/v1/',
      ).toString(),
      'https://example.com/v1/chat/completions',
    );
    expect(
      OpenAiCompatibleClient.chatCompletionsUri(
        'https://example.com/custom/chat/completions',
      ).toString(),
      'https://example.com/custom/chat/completions',
    );
    expect(
      OpenAiCompatibleClient.modelsUri(
        'https://example.com/v1/chat/completions',
      ).toString(),
      'https://example.com/v1/models',
    );
  });

  test('sends authorization, model and messages then parses content', () async {
    late http.Request captured;
    final client = OpenAiCompatibleClient(
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'model': 'actual-model',
            'choices': [
              {
                'message': {'content': '{"ok":true}'},
              },
            ],
          }),
          200,
        );
      }),
    );

    final response = await client.complete(
      config: config(),
      apiKey: 'secret-key',
      messages: const [
        {'role': 'user', 'content': 'hello'},
      ],
    );

    expect(captured.headers['Authorization'], 'Bearer secret-key');
    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['model'], 'test-model');
    expect(body['messages'], isA<List<dynamic>>());
    expect(response.content, '{"ok":true}');
    expect(response.model, 'actual-model');
  });

  test('parses text from content parts', () async {
    final client = OpenAiCompatibleClient(
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'model': 'parts-model',
            'choices': [
              {
                'message': {
                  'content': [
                    {'type': 'text', 'text': 'hello '},
                    {'type': 'text', 'text': 'world'},
                  ],
                },
              },
            ],
          }),
          200,
        ),
      ),
    );

    final response = await client.complete(
      config: config(),
      apiKey: 'key',
      messages: const [],
    );

    expect(response.content, 'hello world');
  });

  test('reports a clear error when output reaches the token limit', () async {
    final client = OpenAiCompatibleClient(
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': null,
                  'reasoning_content': 'still reasoning',
                },
                'finish_reason': 'length',
              },
            ],
          }),
          200,
        ),
      ),
    );

    await expectLater(
      client.complete(
        config: config(),
        apiKey: 'key',
        messages: const [],
      ),
      throwsA(
        isA<AiException>()
            .having(
              (error) => error.kind,
              'kind',
              AiErrorKind.invalidResponse,
            )
            .having(
              (error) => error.message,
              'message',
              contains('Token'),
            ),
      ),
    );
  });

  test('connection test prefers the lightweight models endpoint', () async {
    late http.Request captured;
    final client = OpenAiCompatibleClient(
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response('{"data":[]}', 200);
      }),
    );

    final response = await client.testConnection(
      config: config(),
      apiKey: 'key',
    );

    expect(captured.method, 'GET');
    expect(captured.url.toString(), 'https://example.com/v1/models');
    expect(response.content, isEmpty);
    expect(response.model, 'test-model');
  });

  test('connection test falls back to a 16-token completion', () async {
    final requests = <http.Request>[];
    final client = OpenAiCompatibleClient(
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET') return http.Response('', 404);
        return http.Response(
          jsonEncode({
            'model': 'reasoning-model',
            'choices': [
              {
                'message': {'content': null},
                'finish_reason': 'length',
              },
            ],
          }),
          200,
        );
      }),
    );

    final response = await client.testConnection(
      config: config(),
      apiKey: 'key',
    );

    expect(requests.map((request) => request.method), ['GET', 'POST']);
    final body = jsonDecode(requests.last.body) as Map<String, dynamic>;
    expect(body['max_tokens'], 16);
    expect(response.model, 'reasoning-model');
  });

  test('classifies generic HTTP 429 as rate limit', () async {
    final client = OpenAiCompatibleClient(
      httpClient: MockClient((_) async => http.Response('busy', 429)),
    );

    await expectLater(
      client.complete(config: config(), apiKey: 'key', messages: const []),
      throwsA(
        isA<AiException>().having(
          (error) => error.kind,
          'kind',
          AiErrorKind.rateLimit,
        ),
      ),
    );
  });

  test('classifies non-2xx without leaking API key', () async {
    const secret = 'never-print-this-key';
    final client = OpenAiCompatibleClient(
      httpClient: MockClient(
        (_) async => http.Response('{"error":"unauthorized"}', 401),
      ),
    );

    try {
      await client.complete(
        config: config(),
        apiKey: secret,
        messages: const [],
      );
      fail('expected AiException');
    } on AiException catch (error) {
      expect(error.kind, AiErrorKind.authentication);
      expect(error.toString(), isNot(contains(secret)));
    }
  });

  test('reports timeout and invalid JSON', () async {
    final timeoutClient = OpenAiCompatibleClient(
      httpClient: MockClient((_) async {
        await Completer<void>().future;
        return http.Response('', 200);
      }),
    );
    await expectLater(
      timeoutClient.complete(
        config: config(timeoutSeconds: 0),
        apiKey: 'key',
        messages: const [],
      ),
      throwsA(
        isA<AiException>().having(
          (error) => error.kind,
          'kind',
          AiErrorKind.timeout,
        ),
      ),
    );

    final invalidClient = OpenAiCompatibleClient(
      httpClient: MockClient((_) async => http.Response('not-json', 200)),
    );
    await expectLater(
      invalidClient.complete(
        config: config(),
        apiKey: 'key',
        messages: const [],
      ),
      throwsA(
        isA<AiException>().having(
          (error) => error.kind,
          'kind',
          AiErrorKind.invalidResponse,
        ),
      ),
    );
  });

  test('allows a request-specific timeout override', () async {
    final client = OpenAiCompatibleClient(
      httpClient: MockClient((_) async {
        await Completer<void>().future;
        return http.Response('', 200);
      }),
    );

    await expectLater(
      client.complete(
        config: config(timeoutSeconds: 30),
        apiKey: 'key',
        messages: const [],
        timeoutSeconds: 0,
      ),
      throwsA(
        isA<AiException>()
            .having(
              (error) => error.kind,
              'kind',
              AiErrorKind.timeout,
            )
            .having(
              (error) => error.message,
              'message',
              contains('0 秒'),
            ),
      ),
    );
  });
}
