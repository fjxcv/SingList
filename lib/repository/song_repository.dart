import '../data/db/app_database.dart';

class SongRepository {
  SongRepository(this.db);

  final AppDatabase db;

  Future<int> upsertByTitleArtist(String title, String artist) {
    return db.songDao.upsertByTitleArtist(title, artist);
  }

  Future<void> updateSong(int id, String title, String artist) {
    return db.songDao.updateSong(id, title, artist);
  }

  Future<void> deleteSong(int id) {
    return db.songDao.deleteSong(id);
  }

  Stream<List<Song>> watchAll({String keyword = ''}) {
    return db.songDao.watchAll(keyword: keyword);
  }

  Future<List<Song>> search(String keyword) {
    return db.songDao.searchSongs(keyword);
  }

  Stream<List<Song>> songsByTag(int tagId) {
    return db.songTagDao.songsByTag(tagId);
  }

  Future<void> addTagsToSongs({required List<int> songIds, required List<int> tagIds}) {
    return db.songTagDao.addTagsToSongs(songIds: songIds, tagIds: tagIds);
  }

  Future<void> removeTagsFromSongs({required List<int> songIds, required List<int> tagIds}) {
    return db.songTagDao.removeTagsFromSongs(songIds: songIds, tagIds: tagIds);
  }
}
