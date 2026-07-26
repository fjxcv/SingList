import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sing_list/data/db/app_database.dart';
import 'package:sing_list/repository/playlist_repository.dart';
import 'package:sing_list/repository/song_repository.dart';
import 'package:sing_list/repository/tag_repository.dart';
import 'package:sing_list/service/backup_service.dart';

void main() {
  late AppDatabase database;
  late BackupService service;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    final songRepository = SongRepository(database);
    service = BackupService(
      database,
      songRepository,
      TagRepository(database),
      PlaylistRepository(database),
    );
  });

  tearDown(() => database.close());

  test('restores a version 1 backup without lyrics fields', () async {
    await service.restoreFromJsonString('''
      {
        "version": 1,
        "songs": [
          {"title": "旧版歌曲", "artist": "歌手"}
        ]
      }
    ''');

    final songs = await database.songDao.fetchAllSortedByNorm();
    expect(songs, hasLength(1));
    expect(songs.single.title, '旧版歌曲');
    expect(
      await database.lyricsDao.findForSong(songs.single.id),
      isNull,
    );
  });

  test('restores lyrics onto the matching song id', () async {
    await service.restoreFromJsonString('''
      {
        "version": 2,
        "songs": [
          {
            "title": "新歌",
            "artist": "歌手",
            "lyrics": {
              "japanese": "[空|そら]",
              "chineseTranslation": "天空"
            }
          }
        ]
      }
    ''');

    final song = (await database.songDao.fetchAllSortedByNorm()).single;
    final lyrics = await database.lyricsDao.findForSong(song.id);
    expect(lyrics?.songId, song.id);
    expect(lyrics?.japaneseText, '[空|そら]');
    expect(lyrics?.chineseTranslation, '天空');
  });

  test('restores version 3 lyric metadata and never exports secrets', () async {
    await service.restoreFromJsonString('''
      {
        "version": 3,
        "songs": [
          {
            "title": "新歌",
            "artist": "歌手",
            "lyrics": {
              "japanese": "[空|そら]",
              "chineseTranslation": "天空",
              "originalText": "空",
              "languageCode": "ja",
              "sourceName": "LRCLIB",
              "sourceUrl": "https://lrclib.net/api/get/1",
              "versionLabel": "Album · 3:00",
              "aiProvider": "OpenAI",
              "aiModel": "model",
              "wasManuallyEdited": true
            }
          }
        ]
      }
    ''');

    final song = (await database.songDao.fetchAllSortedByNorm()).single;
    final lyrics = await database.lyricsDao.findForSong(song.id);
    expect(lyrics?.sourceName, 'LRCLIB');
    expect(lyrics?.languageCode, 'ja');
    expect(lyrics?.wasManuallyEdited, isTrue);

    final exported = await service.exportBackup();
    final json = jsonDecode(exported) as Map<String, dynamic>;
    expect(json['version'], 3);
    expect(exported, isNot(contains('apiKey')));
    expect(exported, isNot(contains('Authorization')));
  });
}
