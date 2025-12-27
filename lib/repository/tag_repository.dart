import '../data/db/app_database.dart';

class TagRepository {
  TagRepository(this.db);

  final AppDatabase db;

  Stream<List<Tag>> watchAll() => db.tagDao.watchAll();

  Future<int> create(String name) => db.tagDao.create(name);

  Future<void> rename(int id, String name) => db.tagDao.rename(id, name);

  Future<void> deleteTag(int id) => db.tagDao.deleteTag(id);

  Future<void> ensurePresetTags(List<String> names) => db.tagDao.ensurePresetTags(names);

  Future<Tag?> findByName(String name) => db.tagDao.findByName(name);

  Stream<List<Song>> songsByTag(int tagId) => db.songTagDao.songsByTag(tagId);

  Future<void> attachSongs(int tagId, List<int> songIds) {
    return db.songTagDao.addTagsToSongs(songIds: songIds, tagIds: [tagId]);
  }
}
