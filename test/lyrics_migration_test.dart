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

  test('version 3 migration preserves existing lyrics and adds metadata',
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
          CREATE TABLE song_lyrics (
            song_id INTEGER NOT NULL PRIMARY KEY REFERENCES songs(id)
              ON DELETE CASCADE,
            japanese_text TEXT NOT NULL,
            chinese_translation TEXT NOT NULL DEFAULT '',
            updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
          );
        ''');
        sqliteDatabase.execute('''
          INSERT INTO songs (
            id, title, artist, title_norm, artist_norm, created_at
          ) VALUES (7, 'song', 'artist', 'song', 'artist', 1700000000);
        ''');
        sqliteDatabase.execute('''
          INSERT INTO song_lyrics (
            song_id, japanese_text, chinese_translation, updated_at
          ) VALUES (7, '[空|そら]', '天空', 1700000000);
        ''');
        sqliteDatabase.execute('PRAGMA user_version = 3;');
      },
    );
    final database = AppDatabase(executor);
    addTearDown(database.close);

    final lyrics = await database.lyricsDao.findForSong(7);
    expect(lyrics?.japaneseText, '[空|そら]');
    expect(lyrics?.chineseTranslation, '天空');
    expect(lyrics?.sourceName, isNull);
    expect(lyrics?.wasManuallyEdited, isFalse);
  });
}
