import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sing_list/data/db/app_database.dart';
import 'package:sing_list/repository/song_repository.dart';
import 'package:sing_list/state/providers.dart';
import 'package:sing_list/ui/pages/manual_lyrics_import_page.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  Future<Widget> app() async {
    final songId =
        await SongRepository(database).upsertByTitleArtist('虚月', '歌手');
    final song = await SongRepository(database).findById(songId);
    return ProviderScope(
      overrides: [databaseProvider.overrideWithValue(database)],
      child: MaterialApp(home: ManualLyricsImportPage(song: song!)),
    );
  }

  testWidgets('offers LRCLIB search or direct editing', (tester) async {
    await tester.pumpWidget(await app());

    expect(find.text('从 LRCLIB 查找'), findsOneWidget);
    expect(find.text('直接进入编辑'), findsOneWidget);
  });

  testWidgets('direct editing opens a blank lyrics editor', (tester) async {
    await tester.pumpWidget(await app());

    await tester.tap(find.text('直接进入编辑'));
    await tester.pumpAndSettle();

    expect(find.text('编辑歌词 · 虚月'), findsOneWidget);
    final japaneseField =
        tester.widget<TextField>(find.byType(TextField).first);
    expect(japaneseField.controller!.text, isEmpty);
  });
}
