import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sing_list/ai/ai_config_repository.dart';
import 'package:sing_list/ai/ai_provider_config.dart';
import 'package:sing_list/ai/openai_compatible_client.dart';
import 'package:sing_list/data/db/app_database.dart';
import 'package:sing_list/repository/song_repository.dart';
import 'package:sing_list/state/providers.dart';
import 'package:sing_list/ui/pages/ai_playlist_chat_page.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  AiConfigRepository configRepository({required bool enabled}) {
    return AiConfigRepository(
      _MemoryConfigStore(
        AiProviderConfig(
          provider: AiProvider.custom,
          baseUrl: 'https://example.com/v1',
          model: 'test-model',
          enabled: enabled,
        ).toJson(),
      ),
      _MemoryKeyStore('key'),
    );
  }

  Widget app({
    required AiConfigRepository config,
    OpenAiCompatibleClient? client,
  }) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        aiConfigRepositoryProvider.overrideWithValue(config),
        if (client != null)
          openAiCompatibleClientProvider.overrideWithValue(client),
      ],
      child: const MaterialApp(home: AiPlaylistChatPage()),
    );
  }

  testWidgets('unconfigured AI shows a settings action', (tester) async {
    await SongRepository(database).upsertByTitleArtist('歌曲', '歌手');
    await tester.pumpWidget(app(config: configRepository(enabled: false)));
    await tester.pumpAndSettle();

    expect(find.text('AI 服务尚未启用'), findsOneWidget);
    expect(find.text('前往设置'), findsOneWidget);
  });

  testWidgets('empty catalog is reported without sending a request',
      (tester) async {
    var called = false;
    final client = OpenAiCompatibleClient(
      httpClient: MockClient((_) async {
        called = true;
        return http.Response('', 500);
      }),
    );
    await tester.pumpWidget(
      app(config: configRepository(enabled: true), client: client),
    );
    await tester.pumpAndSettle();

    expect(find.text('曲库为空，请先添加歌曲'), findsOneWidget);
    expect(called, isFalse);
  });

  testWidgets('loading disables another send and exposes cancel',
      (tester) async {
    await SongRepository(database).upsertByTitleArtist('歌曲', '歌手');
    final entered = Completer<void>();
    final client = OpenAiCompatibleClient(
      httpClient: MockClient((_) async {
        entered.complete();
        await Completer<void>().future;
        return http.Response('', 200);
      }),
    );
    await tester.pumpWidget(
      app(config: configRepository(enabled: true), client: client),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('ai-playlist-input')),
      '推荐歌曲',
    );
    await tester.tap(find.byKey(const Key('ai-playlist-send')));
    await tester.pump();
    await entered.future;

    expect(find.byKey(const Key('ai-playlist-send')), findsNothing);
    expect(find.byKey(const Key('ai-playlist-cancel')), findsOneWidget);
    final firstChip = tester.widget<ActionChip>(find.byType(ActionChip).first);
    expect(firstChip.onPressed, isNull);

    await tester.tap(find.byKey(const Key('ai-playlist-cancel')));
    await tester.pumpAndSettle();
    expect(find.textContaining('已取消本次请求'), findsOneWidget);
  });

  testWidgets('a failed follow-up preserves the last valid result',
      (tester) async {
    final songId =
        await SongRepository(database).upsertByTitleArtist('保留的歌曲', '歌手');
    var callCount = 0;
    final client = OpenAiCompatibleClient(
      httpClient: MockClient((_) async {
        callCount++;
        if (callCount > 1) {
          return http.Response('server error', 500);
        }
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': jsonEncode({
                    'reply': '这是推荐',
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
    await tester.pumpWidget(
      app(config: configRepository(enabled: true), client: client),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('ai-playlist-input')),
      '第一次请求',
    );
    await tester.tap(find.byKey(const Key('ai-playlist-send')));
    await tester.pumpAndSettle();
    expect(find.text('保留的歌曲'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('ai-playlist-input')),
      '失败的追问',
    );
    await tester.tap(find.byKey(const Key('ai-playlist-send')));
    await tester.pumpAndSettle();

    expect(find.text('保留的歌曲'), findsOneWidget);
    expect(find.textContaining('服务端错误'), findsOneWidget);
    expect(
      find.byKey(const Key('ai-playlist-input')).evaluate().single.widget,
      isA<TextField>().having(
        (field) => field.controller?.text,
        'preserved input',
        '失败的追问',
      ),
    );
  });

  testWidgets(
      'external song requires confirmation and reuses an existing local id',
      (tester) async {
    await SongRepository(database).upsertByTitleArtist('已有歌曲', '已有歌手');
    final client = OpenAiCompatibleClient(
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': jsonEncode({
                    'reply': '可以发现一首新歌',
                    'needsClarification': false,
                    'clarifyingQuestion': null,
                    'playlistTitle': '发现歌单',
                    'recommendations': [],
                    'externalRecommendations': [
                      {
                        'title': '已有歌曲',
                        'artist': '已有歌手',
                        'reason': '可能符合你的偏好',
                      },
                    ],
                  }),
                },
              },
            ],
          }),
          200,
          headers: const {
            'content-type': 'application/json; charset=utf-8',
          },
        ),
      ),
    );
    await tester.pumpWidget(
      app(config: configRepository(enabled: true), client: client),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch).first);
    await tester.enterText(
      find.byKey(const Key('ai-playlist-input')),
      '推荐没收藏的新歌',
    );
    await tester.tap(find.byKey(const Key('ai-playlist-send')));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, '加入曲库'));
    await tester.pumpAndSettle();
    expect(await SongRepository(database).fetchAllSortedByNorm(), hasLength(1));

    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();
    expect(await SongRepository(database).fetchAllSortedByNorm(), hasLength(1));

    await tester.tap(find.widgetWithText(OutlinedButton, '加入曲库'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '确认加入'));
    await tester.pumpAndSettle();

    final songs = await SongRepository(database).fetchAllSortedByNorm();
    expect(songs, hasLength(1));
    expect(find.text('已有歌曲'), findsOneWidget);
  });

  testWidgets('playlist is not created before final confirmation',
      (tester) async {
    final songId =
        await SongRepository(database).upsertByTitleArtist('待保存歌曲', '歌手');
    final client = OpenAiCompatibleClient(
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': jsonEncode({
                    'reply': '推荐如下',
                    'needsClarification': false,
                    'clarifyingQuestion': null,
                    'playlistTitle': '确认测试歌单',
                    'recommendations': [
                      {'songId': songId, 'reason': '适合'},
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
        ),
      ),
    );
    await tester.pumpWidget(
      app(config: configRepository(enabled: true), client: client),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('ai-playlist-input')),
      '生成歌单',
    );
    await tester.tap(find.byKey(const Key('ai-playlist-send')));
    await tester.pumpAndSettle();

    final createButton = find.byKey(const Key('ai-playlist-create-normal'));
    await tester.scrollUntilVisible(
      createButton,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(createButton);
    await tester.pumpAndSettle();
    expect(await database.select(database.playlists).get(), isEmpty);

    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();
    expect(await database.select(database.playlists).get(), isEmpty);
  });

  testWidgets('disposing the page cancels without setState errors',
      (tester) async {
    await SongRepository(database).upsertByTitleArtist('歌曲', '歌手');
    final entered = Completer<void>();
    final client = OpenAiCompatibleClient(
      httpClient: MockClient((_) async {
        entered.complete();
        await Completer<void>().future;
        return http.Response('', 200);
      }),
    );
    await tester.pumpWidget(
      app(config: configRepository(enabled: true), client: client),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('ai-playlist-input')),
      '推荐歌曲',
    );
    await tester.tap(find.byKey(const Key('ai-playlist-send')));
    await tester.pump();
    await entered.future;

    await tester.pumpWidget(const SizedBox());
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}

class _MemoryConfigStore implements AiConfigStore {
  _MemoryConfigStore(this.value);

  Map<String, dynamic>? value;

  @override
  Future<Map<String, dynamic>?> loadAiConfig() async => value;

  @override
  Future<void> saveAiConfig(Map<String, dynamic> config) async {
    value = config;
  }
}

class _MemoryKeyStore implements ApiKeyStore {
  _MemoryKeyStore(this.value);

  String? value;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async => this.value = value;
}
