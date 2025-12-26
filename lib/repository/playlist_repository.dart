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

  Future<List<Song>> songsInPlaylistSortedByNorm(int playlistId) {
    return db.playlistDao.songsInPlaylistSortedByNorm(playlistId);
  }

  Future<Playlist?> findById(int id) {
    return db.playlistDao.findById(id);
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
}
