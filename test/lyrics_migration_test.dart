import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sing_list/data/db/app_database.dart';

void main() {
  test('version 2 migration preserves songs and creates lyrics table',
      () async {
    final executor = NativeDatabase.memory(
      setup: (sqliteDatabase) {
        sqliteDatabase.execute('''
          CREATE TABLE songs (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            artist TEXT NOT NULL,
            title_norm TEXT NOT NULL,
            artist_norm TEXT NOT NULL,
            created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
            UNIQUE(title_norm, artist_norm)
          );
        ''');
        sqliteDatabase.execute('''
          INSERT INTO songs (
            title, artist, title_norm, artist_norm, created_at
          ) VALUES (
            'existing song', 'artist', 'existing song', 'artist', 1700000000
          );
        ''');
        sqliteDatabase.execute('PRAGMA user_version = 2;');
      },
    );
    final database = AppDatabase(executor);
    addTearDown(database.close);

    final songs = await database.songDao.fetchAllSortedByNorm();
    expect(songs, hasLength(1));
    expect(songs.single.title, 'existing song');

    await database.lyricsDao.save(
      songId: songs.single.id,
      japanese: '[\u7A7A|\u305D\u3089]',
      translation: '\u5929\u7A7A',
    );
    expect(
      (await database.lyricsDao.findForSong(songs.single.id))?.japaneseText,
      '[\u7A7A|\u305D\u3089]',
    );
  });
}
