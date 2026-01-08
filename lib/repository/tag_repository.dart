import '../data/db/app_database.dart';

const Set<String> protectedTagNames = {'开嗓', '收尾', '合唱'};

class TagRepository {
  TagRepository(this.db);

  final AppDatabase db;

  Stream<List<Tag>> watchAll() => db.tagDao.watchAll();

  Future<int> create(String name) => db.tagDao.create(name);

  Future<void> rename(int id, String name) async {
    final tag = await db.tagDao.findById(id);
    if (tag != null && protectedTagNames.contains(tag.name)) {
      throw Exception('默认标签不可修改');
    }
    await db.tagDao.rename(id, name);
  }

  Future<void> deleteTag(int id) async {
    final tag = await db.tagDao.findById(id);
    if (tag != null && protectedTagNames.contains(tag.name)) {
      throw Exception('默认标签不可删除');
    }
    await db.tagDao.deleteTag(id);
  }

  Future<void> ensurePresetTags(List<String> names) => db.tagDao.ensurePresetTags(names);

  Future<Tag?> findByName(String name) => db.tagDao.findByName(name);

  Stream<List<Song>> songsByTag(int tagId) => db.songTagDao.songsByTag(tagId);

  Future<void> attachSongs(int tagId, List<int> songIds) {
    return db.songTagDao.addTagsToSongs(songIds: songIds, tagIds: [tagId]);
  }

  Future<void> detachSongs(int tagId, List<int> songIds) {
    return db.songTagDao.removeTagsFromSongs(songIds: songIds, tagIds: [tagId]);
  }
}
