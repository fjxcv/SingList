import 'package:drift/drift.dart';

import '../data/db/app_database.dart';

class TagRepository {
  final AppDatabase db;
  TagRepository(this.db);

  Stream<List<Tag>> watchAll() => (db.select(db.tags)..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();

  Future<int> create(String name) => db.into(db.tags).insertOnConflictUpdate(TagsCompanion.insert(name: name));

  Future<void> rename(int id, String name) async {
    await (db.update(db.tags)..where((t) => t.id.equals(id))).write(TagsCompanion(name: Value(name)));
  }

  Future<void> delete(int id) async {
    await db.transaction(() async {
      await (db.delete(db.songTags)..where((t) => t.tagId.equals(id))).go();
      await (db.delete(db.tags)..where((t) => t.id.equals(id))).go();
    });
  }

  Stream<List<Song>> songsByTag(int tagId) {
    final query = db.select(db.songs).join([
      innerJoin(db.songTags, db.songTags.songId.equalsExp(db.songs.id)),
    ]);
    query.where(db.songTags.tagId.equals(tagId));
    query.orderBy([OrderingTerm.asc(db.songs.title)]);
    return query.watch().map((rows) => rows.map((r) => r.readTable(db.songs)).toList());
  }

  Future<void> attachSongs(int tagId, List<int> songIds) async {
    for (final id in songIds) {
      await db.into(db.songTags).insertOnConflictUpdate(SongTagsCompanion.insert(songId: id, tagId: tagId));
    }
  }
}
