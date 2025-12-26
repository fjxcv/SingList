import '../data/db/app_database.dart';

class TagRepository {
  TagRepository(this.db);

  final AppDatabase db;

  Stream<List<Tag>> watchAll() => db.tagDao.watchAll();

  Future<int> create(String name) => db.tagDao.create(name);

  Future<void> rename(int id, String name) => db.tagDao.rename(id, name);

  Future<void> delete(int id) => db.tagDao.delete(id);

  Future<void> ensurePresetTags(List<String> names) => db.tagDao.ensurePresetTags(names);

  Future<Tag?> findByName(String name) => db.tagDao.findByName(name);
}
