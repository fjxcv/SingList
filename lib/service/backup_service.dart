import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/db/app_database.dart';
import '../repository/playlist_repository.dart';
import '../repository/song_repository.dart';
import '../repository/tag_repository.dart';

class BackupService {
  BackupService(this.db, this.songRepo, this.tagRepo, this.playlistRepo);

  final AppDatabase db;
  final SongRepository songRepo;
  final TagRepository tagRepo;
  final PlaylistRepository playlistRepo;

  Future<String> exportBackup() async {
    final songs = await db.songDao.fetchAllSortedByNorm();
    final tags = await db.tagDao.watchAll().first;
    final playlists = await db.playlistDao.watchByType(PlaylistType.normal).first;
    final queues = await db.playlistDao.watchByType(PlaylistType.kQueue).first;

    final payload = <String, dynamic>{
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'songs': songs
          .map((s) => {
                'title': s.title,
                'artist': s.artist,
              })
          .toList(),
      'tags': tags.map((t) => t.name).toList(),
      'playlists': [
        for (final pl in playlists)
          {
            'name': pl.name,
            'type': 'normal',
            'songs': (await db.playlistDao.songsInPlaylistSortedByNorm(pl.id))
                .map((s) => {'title': s.title, 'artist': s.artist})
                .toList(),
          },
        for (final pl in queues)
          {
            'name': pl.name,
            'type': 'kQueue',
            'songs': (await db.queueDao.queueItemsWithSongs(pl.id).first)
                .map((e) => {'title': e.song.title, 'artist': e.song.artist})
                .toList(),
          },
      ],
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Future<void> restoreFromFile(String path) async {
    final raw = await File(path).readAsString();
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final songList = data['songs'] as List<dynamic>? ?? [];
    for (final item in songList) {
      final map = item as Map<String, dynamic>;
      await songRepo.addSong(map['title'] as String, map['artist'] as String);
    }
  }

  Future<File> writeBackupToDocuments() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'singlist_backup_${DateTime.now().millisecondsSinceEpoch}.json'));
    await file.writeAsString(await exportBackup());
    return file;
  }
}
