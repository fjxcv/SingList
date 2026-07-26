import 'package:intl/intl.dart';
import 'package:drift/drift.dart';

import '../data/db/app_database.dart';

class PlaylistRepository {
  PlaylistRepository(this.db);

  final AppDatabase db;

  Stream<List<Playlist>> watchByType(PlaylistType type) {
    return db.playlistDao.watchByType(type);
  }

  Future<int> create(String name, PlaylistType type) {
    return db.playlistDao.createPlaylist(name, type);
  }

  Future<void> delete(int id) {
    return db.playlistDao.deletePlaylist(id);
  }

  Stream<List<Song>> songsInPlaylist(int playlistId) {
    return db.playlistDao.songsInPlaylist(playlistId);
  }

  Future<void> addSongsToPlaylist(int playlistId, List<int> songIds) {
    return db.playlistDao.addSongsToPlaylist(playlistId, songIds);
  }

  Future<void> removeSongsFromPlaylist(int playlistId, List<int> songIds) {
    return db.playlistDao.removeSongsFromPlaylist(playlistId, songIds);
  }

  Future<List<Song>> songsInPlaylistSortedByNorm(int playlistId) {
    return db.playlistDao.songsInPlaylistSortedByNorm(playlistId);
  }

  Future<Playlist?> findById(int id) {
    return db.playlistDao.findById(id);
  }

  Future<void> rename(int id, String name) {
    return db.playlistDao.renamePlaylist(id, name);
  }

  Stream<List<QueueItemWithSong>> queueItems(int playlistId) {
    return db.queueDao.queueItemsWithSongs(playlistId);
  }

  Future<int> enqueue(int playlistId, int songId, int position) {
    return db.queueDao.enqueue(playlistId, songId, position);
  }

  Future<void> reorderQueue(int playlistId, List<int> itemIdsInOrder) {
    return db.queueDao.reorderQueue(playlistId, itemIdsInOrder);
  }

  Future<void> removeQueueItem(int id) {
    return db.queueDao.removeQueueItem(id);
  }

  Future<void> clearQueue(int playlistId) {
    return db.queueDao.clearQueue(playlistId);
  }

  Future<Playlist> createQueueWithSongs(List<int> songIds) async {
    final timestamp = DateFormat('yyyy-MM-dd/HH:mm:ss').format(DateTime.now());
    return AiPlaylistRepositoryOperations(this)
        .createQueueWithSongsNamed(timestamp, songIds);
  }
}

extension AiPlaylistRepositoryOperations on PlaylistRepository {
  Future<List<Playlist>> fetchByType(PlaylistType type) {
    return watchByType(type).first;
  }

  Future<Playlist> createNormalWithSongs(
    String name,
    List<int> songIds,
  ) {
    return db.transaction(() async {
      final playlistId = await create(name, PlaylistType.normal);
      final seen = <int>{};
      var position = 0;
      for (final songId in songIds) {
        if (!seen.add(songId)) continue;
        await db.into(db.playlistSongs).insert(
              PlaylistSongsCompanion.insert(
                playlistId: playlistId,
                songId: songId,
                position: Value(position++),
              ),
            );
      }
      final playlist = await findById(playlistId);
      if (playlist == null) {
        throw StateError('创建普通歌单失败');
      }
      return playlist;
    });
  }

  Future<Playlist> createQueueWithSongsNamed(
    String name,
    List<int> songIds,
  ) {
    return db.transaction(() async {
      final queueId = await create(name, PlaylistType.kQueue);
      for (var index = 0; index < songIds.length; index++) {
        await db.into(db.queueItems).insert(
              QueueItemsCompanion.insert(
                playlistId: queueId,
                songId: songIds[index],
                position: Value(index),
              ),
            );
      }
      final playlist = await findById(queueId);
      if (playlist == null) {
        throw StateError('创建 KQueue 失败');
      }
      return playlist;
    });
  }

  Future<void> appendSongsToQueue(
    int playlistId,
    List<int> songIds,
  ) {
    return db.transaction(() async {
      final playlist = await findById(playlistId);
      if (playlist == null || playlist.type != PlaylistType.kQueue) {
        throw StateError('目标 KQueue 不存在');
      }
      final existing = await (db.select(db.queueItems)
            ..where((item) => item.playlistId.equals(playlistId))
            ..orderBy([(item) => OrderingTerm.asc(item.position)]))
          .get();
      var position = existing.isEmpty
          ? 0
          : existing
                  .map((item) => item.position)
                  .reduce((a, b) => a > b ? a : b) +
              1;
      for (final songId in songIds) {
        await db.into(db.queueItems).insert(
              QueueItemsCompanion.insert(
                playlistId: playlistId,
                songId: songId,
                position: Value(position++),
              ),
            );
      }
    });
  }
}
