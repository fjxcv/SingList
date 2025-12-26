import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

class Songs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get artist => text()();
  TextColumn get titleNorm => text()();
  TextColumn get artistNorm => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => ['UNIQUE(title_norm, artist_norm)'];
}

class Tags extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class SongTags extends Table {
  IntColumn get songId => integer().references(Songs, #id)();
  IntColumn get tagId => integer().references(Tags, #id)();

  @override
  Set<Column<Object>> get primaryKey => {songId, tagId};
}

enum PlaylistType { normal, kQueue }

class Playlists extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get type => intEnum<PlaylistType>()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class PlaylistEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get playlistId => integer().references(Playlists, #id)();
  IntColumn get songId => integer().references(Songs, #id)();
  IntColumn get position => integer().withDefault(const Constant(0))();

  @override
  List<String> get customConstraints => ['UNIQUE(playlist_id, song_id)'];
}

class QueueItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get playlistId => integer().references(Playlists, #id)();
  IntColumn get songId => integer().references(Songs, #id)();
  IntColumn get position => integer().withDefault(const Constant(0))();
}

@DriftDatabase(
  tables: [Songs, Tags, SongTags, Playlists, PlaylistEntries, QueueItems],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  Future<void> seed() async {
    final preset = ['开嗓', '气氛', '收尾'];
    for (final name in preset) {
      await into(tags).insertOnConflictUpdate(TagsCompanion.insert(name: name));
    }
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'k_sing.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

Future<AppDatabase> createDatabase() async {
  final db = AppDatabase();
  await db.customStatement('PRAGMA foreign_keys = ON');
  await db.seed();
  return db;
}
