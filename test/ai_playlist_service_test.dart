import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sing_list/ai/ai_exception.dart';
import 'package:sing_list/ai/ai_provider_config.dart';
import 'package:sing_list/ai/openai_compatible_client.dart';
import 'package:sing_list/ai_playlist/ai_playlist_models.dart';
import 'package:sing_list/ai_playlist/ai_playlist_prompt.dart';
import 'package:sing_list/ai_playlist/ai_playlist_service.dart';
import 'package:sing_list/ai_playlist/song_catalog_service.dart';
import 'package:sing_list/data/db/app_database.dart';
import 'package:sing_list/repository/song_repository.dart';

void main() {
  late AppDatabase database;
  late SongRepository songs;

  const config = AiProviderConfig(
    provider: AiProvider.custom,
    baseUrl: 'https://example.com/v1',
    model: 'test-model',
    enabled: true,
  );

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    songs = SongRepository(database);
  });

  tearDown(() => database.close());

  test('reuses compatible client and sends catalog, switch and current input',
      () async {
    final songId = await songs.upsertByTitleArtist('真实歌曲', '歌手');
    late http.Request captured;
    final client = OpenAiCompatibleClient(
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'model': 'actual-model',
            'choices': [
              {
                'message': {
                  'content': jsonEncode({
                    'reply': '推荐一首',
                    'needsClarification': false,
                    'clarifyingQuestion': null,
                    'playlistTitle': '测试歌单',
                    'recommendations': [
                      {'songId': songId, 'reason': '符合需求'},
                    ],
                    'externalRecommendations': [],
                  }),
                },
              },
            ],
          }),
          200,
          headers: const {
            'content-type': 'application/json; charset=utf-8',
          },
        );
      }),
    );
    final service = AiPlaylistService(
      client: client,
      catalogService: SongCatalogService(database),
    );

    final result = await service.send(
      config: config,
      apiKey: 'secret-key',
      userMessage: '想唱轻松的歌',
      history: const [],
      allowExternal: true,
    );

    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    final messages = body['messages'] as List<dynamic>;
    expect(messages.first['role'], 'system');
    expect(messages[1]['content'], contains('"allowExternal":true'));
    expect(messages[1]['content'], contains('"id":$songId'));
    expect(messages.last['content'], '想唱轻松的歌');
    expect(captured.body, isNot(contains('secret-key')));
    expect(result.result.recommendations.single.song.id, songId);
    expect(result.actualModel, 'actual-model');
  });

  test('keeps only the most recent eight conversation rounds', () async {
    final songId = await songs.upsertByTitleArtist('歌曲', '歌手');
    late List<dynamic> capturedMessages;
    final client = OpenAiCompatibleClient(
      httpClient: MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        capturedMessages = body['messages'] as List<dynamic>;
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': jsonEncode({
                    'reply': '完成',
                    'needsClarification': false,
                    'clarifyingQuestion': null,
                    'playlistTitle': '歌单',
                    'recommendations': [
                      {'songId': songId, 'reason': '理由'},
                    ],
                    'externalRecommendations': [],
                  }),
                },
              },
            ],
          }),
          200,
          headers: const {
            'content-type': 'application/json; charset=utf-8',
          },
        );
      }),
    );
    final history = [
      for (var index = 0; index < 20; index++)
        AiPlaylistHistoryMessage(
          role: index.isEven ? 'user' : 'assistant',
          content: 'history-$index',
        ),
    ];

    await AiPlaylistService(
      client: client,
      catalogService: SongCatalogService(database),
    ).send(
      config: config,
      apiKey: 'key',
      userMessage: 'current',
      history: history,
      allowExternal: false,
    );

    expect(
      capturedMessages,
      hasLength(AiPlaylistPrompt.maxHistoryMessages + 3),
    );
    expect(capturedMessages[2]['content'], 'history-4');
    expect(capturedMessages.last['content'], 'current');
  });

  test('empty catalog fails before calling AI', () async {
    var called = false;
    final service = AiPlaylistService(
      client: OpenAiCompatibleClient(
        httpClient: MockClient((_) async {
          called = true;
          return http.Response('', 500);
        }),
      ),
      catalogService: SongCatalogService(database),
    );

    await expectLater(
      service.send(
        config: config,
        apiKey: 'key',
        userMessage: '推荐歌曲',
        history: const [],
        allowExternal: false,
      ),
      throwsA(
        isA<AiException>().having(
          (error) => error.message,
          'message',
          contains('曲库为空'),
        ),
      ),
    );
    expect(called, isFalse);
  });

  test('cancellation stops an in-flight compatible client request', () async {
    await songs.upsertByTitleArtist('歌曲', '歌手');
    final enteredRequest = Completer<void>();
    final client = OpenAiCompatibleClient(
      httpClient: MockClient((_) async {
        enteredRequest.complete();
        await Completer<void>().future;
        return http.Response('', 200);
      }),
    );
    final token = AiCancellationToken();
    final future = AiPlaylistService(
      client: client,
      catalogService: SongCatalogService(database),
    ).send(
      config: config,
      apiKey: 'key',
      userMessage: '推荐歌曲',
      history: const [],
      allowExternal: false,
      cancellationToken: token,
    );
    await enteredRequest.future;
    token.cancel();

    await expectLater(
      future,
      throwsA(
        isA<AiException>().having(
          (error) => error.kind,
          'kind',
          AiErrorKind.cancelled,
        ),
      ),
    );
  });
}
