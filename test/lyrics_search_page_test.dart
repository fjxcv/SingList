import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sing_list/data/db/app_database.dart';
import 'package:sing_list/lyrics/lyric_candidate.dart';
import 'package:sing_list/lyrics/lyric_search_service.dart';
import 'package:sing_list/repository/song_repository.dart';
import 'package:sing_list/state/providers.dart';
import 'package:sing_list/ui/pages/lyrics_search_page.dart';

class _FakeLyricSearchService extends LyricSearchService {
  @override
  Future<List<LyricCandidate>> search({
    required String trackName,
    required String artistName,
  }) async {
    return const [
      LyricCandidate(
        id: 42,
        trackName: '虚月',
        artistName: '歌手',
        albumName: '专辑',
        durationSeconds: 180,
        lyrics: '雨が降った\n花が散った',
        instrumental: false,
      ),
    ];
  }
}

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  testWidgets('LRCLIB result can open the editor without AI', (tester) async {
    final songId =
        await SongRepository(database).upsertByTitleArtist('虚月', '歌手');
    final song = await SongRepository(database).findById(songId);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          lyricSearchServiceProvider.overrideWithValue(
            _FakeLyricSearchService(),
          ),
        ],
        child: MaterialApp(
          home: LyricsSearchPage(
            song: song!,
            resultAction: LyricsSearchResultAction.editDirectly,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('从 LRCLIB 查找'), findsOneWidget);
    await tester.tap(find.text('来源：LRCLIB'));
    await tester.pumpAndSettle();

    expect(find.text('编辑歌词 · 虚月'), findsOneWidget);
    final japaneseField =
        tester.widget<TextField>(find.byType(TextField).first);
    expect(japaneseField.controller!.text, '雨が降った\n花が散った');
  });
}
