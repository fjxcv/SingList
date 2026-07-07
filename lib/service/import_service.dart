import '../data/db/app_database.dart';
import '../repository/song_repository.dart';
import 'import_parser.dart';

enum ImportTarget { library, normalPlaylist, kQueue }

class ImportOptions {
  const ImportOptions({
    required this.target,
    this.playlistId,
    this.playlistName,
  });

  final ImportTarget target;
  final int? playlistId;
  final String? playlistName;
}

class ImportResult {
  const ImportResult({
    required this.created,
    required this.existed,
    required this.errorCount,
    this.queuePlaylistId,
  });

  final int created;
  final int existed;
  final int errorCount;
  final int? queuePlaylistId;
}

class ImportService {
  ImportService(this.db);

  final AppDatabase db;

  Future<ImportResult> executeImport(ParseResult parseResult, ImportOptions options) async {
    if (options.target == ImportTarget.kQueue) {
      return _importToKQueue(parseResult, options);
    }

    var created = 0;
    var existed = 0;
    final songIds = <int>[];

    for (final parsed in parseResult.songs) {
      final result = await db.songDao.addSong(parsed.title, parsed.artist);
      final songId = await db.songDao.upsertByTitleArtist(parsed.title, parsed.artist);
      songIds.add(songId);
      if (result == SongUpsertResult.created) {
        created++;
      } else {
        existed++;
      }
    }

    if (options.target == ImportTarget.normalPlaylist && options.playlistId != null) {
      await db.playlistDao.addSongsToPlaylist(options.playlistId!, songIds);
    }

    return ImportResult(
      created: created,
      existed: existed,
      errorCount: parseResult.errorLines.length,
    );
  }

  Future<ImportResult> _importToKQueue(ParseResult parseResult, ImportOptions options) async {
    var playlistId = options.playlistId;
    if (playlistId == null) {
      final name = options.playlistName?.trim().isNotEmpty == true
          ? options.playlistName!.trim()
          : '导入队列 ${DateTime.now().toIso8601String().substring(0, 16)}';
      playlistId = await db.playlistDao.createPlaylist(name, PlaylistType.kQueue);
    }

    var created = 0;
    var existed = 0;
    final existing = await db.queueDao.queueItemsWithSongs(playlistId).first;
    var position = existing.length;

    for (final parsed in parseResult.songs) {
      final result = await db.songDao.addSong(parsed.title, parsed.artist);
      final songId = await db.songDao.upsertByTitleArtist(parsed.title, parsed.artist);
      if (result == SongUpsertResult.created) {
        created++;
      } else {
        existed++;
      }
      await db.queueDao.enqueue(playlistId, songId, position++);
    }

    return ImportResult(
      created: created,
      existed: existed,
      errorCount: parseResult.errorLines.length,
      queuePlaylistId: playlistId,
    );
  }
}

String importTargetLabel(ImportTarget target) {
  switch (target) {
    case ImportTarget.library:
      return '曲库';
    case ImportTarget.normalPlaylist:
      return '普通歌单';
    case ImportTarget.kQueue:
      return 'KQueue 队列';
  }
}
