import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../service/normalize.dart';

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

class PlaylistSongs extends Table {
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
  tables: [Songs, Tags, SongTags, Playlists, PlaylistSongs, QueueItems],
  daos: [SongDao, TagDao, SongTagDao, PlaylistDao, QueueDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  SongDao get songDao => SongDao(this);
  TagDao get tagDao => TagDao(this);
  SongTagDao get songTagDao => SongTagDao(this);
  PlaylistDao get playlistDao => PlaylistDao(this);
  QueueDao get queueDao => QueueDao(this);

  @override
  int get schemaVersion => 1;

  Future<void> seed() async {
    await tagDao.ensurePresetTags(['开嗓', '气氛', '收尾']);
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

@DriftAccessor(tables: [Songs])
class SongDao extends DatabaseAccessor<AppDatabase> with _$SongDaoMixin {
  SongDao(super.db);

  Future<int> upsertByTitleArtist(String title, String artist) async {
    final titleNorm = normalizeTitle(title);
    final artistNorm = normalizeArtist(artist);
    final existing = await (select(songs)
          ..where(
            (tbl) => tbl.titleNorm.equals(titleNorm) &
                tbl.artistNorm.equals(artistNorm),
          ))
        .getSingleOrNull();
    if (existing != null) return existing.id;

    return into(songs).insert(
      SongsCompanion.insert(
        title: title,
        artist: artist,
        titleNorm: titleNorm,
        artistNorm: artistNorm,
      ),
    );
  }

  Future<void> updateSong(int id, String title, String artist) async {
    final titleNorm = normalizeTitle(title);
    final artistNorm = normalizeArtist(artist);
    await (update(songs)..where((tbl) => tbl.id.equals(id))).write(
      SongsCompanion(
        title: Value(title),
        artist: Value(artist),
        titleNorm: Value(titleNorm),
        artistNorm: Value(artistNorm),
      ),
    );
  }

  Future<void> deleteSong(int id) async {
    await transaction(() async {
      await (delete(db.songTags)..where((t) => t.songId.equals(id))).go();
      await (delete(db.queueItems)..where((t) => t.songId.equals(id))).go();
      await (delete(db.playlistSongs)..where((t) => t.songId.equals(id))).go();
      await (delete(songs)..where((t) => t.id.equals(id))).go();
    });
  }

  Stream<List<Song>> watchAll({String keyword = ''}) {
    final query = select(songs)
      ..orderBy([(s) => OrderingTerm.desc(s.createdAt)]);
    if (keyword.trim().isNotEmpty) {
      final like = '%${keyword.trim()}%';
      query.where((tbl) => tbl.title.like(like) | tbl.artist.like(like));
    }
    return query.watch();
  }

  Future<List<Song>> searchSongs(String keyword) {
    final like = '%${keyword.trim()}%';
    return (select(songs)
          ..where((tbl) => tbl.title.like(like) | tbl.artist.like(like)))
        .get();
  }

  Future<List<Song>> fetchAllSortedByNorm() {
    return (select(songs)
          ..orderBy([
            (tbl) => OrderingTerm.asc(tbl.titleNorm),
            (tbl) => OrderingTerm.asc(tbl.artistNorm),
          ]))
        .get();
  }

  Future<List<Song>> fetchSongsByTagSorted(int tagId) {
    final query = select(songs).join([
      innerJoin(songTags, songTags.songId.equalsExp(songs.id)),
    ]);
    query.where(songTags.tagId.equals(tagId));
    query.orderBy([
      OrderingTerm.asc(songs.titleNorm),
      OrderingTerm.asc(songs.artistNorm),
    ]);
    return query.watch().first.then(
          (rows) => rows.map((row) => row.readTable(songs)).toList(),
        );
  }
}

@DriftAccessor(tables: [Tags])
class TagDao extends DatabaseAccessor<AppDatabase> with _$TagDaoMixin {
  TagDao(super.db);

  Stream<List<Tag>> watchAll() {
    return (select(tags)..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();
  }

  Future<Tag?> findByName(String name) {
    return (select(tags)..where((tbl) => tbl.name.equals(name))).getSingleOrNull();
  }

  Future<int> create(String name) {
    return into(tags).insertOnConflictUpdate(TagsCompanion.insert(name: name));
  }

  Future<void> rename(int id, String name) async {
    await (update(tags)..where((t) => t.id.equals(id)))
        .write(TagsCompanion(name: Value(name)));
  }

  Future<void> delete(int id) async {
    await transaction(() async {
      await (delete(db.songTags)..where((t) => t.tagId.equals(id))).go();
      await (delete(tags)..where((t) => t.id.equals(id))).go();
    });
  }

  Future<void> ensurePresetTags(List<String> names) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(
        tags,
        names.map((name) => TagsCompanion.insert(name: name)).toList(),
      );
    });
  }
}

@DriftAccessor(tables: [SongTags, Songs, Tags])
class SongTagDao extends DatabaseAccessor<AppDatabase> with _$SongTagDaoMixin {
  SongTagDao(super.db);

  Future<void> addTagsToSongs({required List<int> songIds, required List<int> tagIds}) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(
        songTags,
        [
          for (final songId in songIds)
            for (final tagId in tagIds)
              SongTagsCompanion.insert(songId: songId, tagId: tagId),
        ],
      );
    });
  }

  Future<void> removeTagsFromSongs({required List<int> songIds, required List<int> tagIds}) async {
    await batch((b) {
      for (final songId in songIds) {
        b.deleteWhere(
          songTags,
          (tbl) => tbl.songId.equals(songId) & tbl.tagId.isIn(tagIds),
        );
      }
    });
  }

  Stream<List<Song>> songsByTag(int tagId) {
    final query = select(songs).join([
      innerJoin(songTags, songTags.songId.equalsExp(songs.id)),
    ]);
    query.where(songTags.tagId.equals(tagId));
    query.orderBy([OrderingTerm.asc(songs.title)]);
    return query.watch().map((rows) => rows.map((r) => r.readTable(songs)).toList());
  }
}

@DriftAccessor(tables: [Playlists, PlaylistSongs, Songs])
class PlaylistDao extends DatabaseAccessor<AppDatabase> with _$PlaylistDaoMixin {
  PlaylistDao(super.db);

  Stream<List<Playlist>> watchByType(PlaylistType type) {
    return (select(playlists)
          ..where((tbl) => tbl.type.equalsValue(type))
          ..orderBy([(p) => OrderingTerm.desc(p.createdAt)]))
        .watch();
  }

  Future<int> createPlaylist(String name, PlaylistType type) {
    return into(playlists).insert(PlaylistsCompanion.insert(name: name, type: type));
  }

  Future<void> deletePlaylist(int id) async {
    await transaction(() async {
      await (delete(db.playlistSongs)..where((t) => t.playlistId.equals(id))).go();
      await (delete(db.queueItems)..where((t) => t.playlistId.equals(id))).go();
      await (delete(playlists)..where((t) => t.id.equals(id))).go();
    });
  }

  Future<Playlist?> findById(int id) {
    return (select(playlists)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  Stream<List<Song>> songsInPlaylist(int playlistId) {
    final query = select(songs).join([
      innerJoin(playlistSongs, playlistSongs.songId.equalsExp(songs.id)),
    ]);
    query.where(playlistSongs.playlistId.equals(playlistId));
    query.orderBy([OrderingTerm.asc(playlistSongs.position)]);
    return query.watch().map((rows) => rows.map((r) => r.readTable(songs)).toList());
  }

  Future<void> addSongsToPlaylist(int playlistId, List<int> songIds) async {
    await transaction(() async {
      final existingCount = await (select(playlistSongs)
            ..where((tbl) => tbl.playlistId.equals(playlistId)))
          .get();
      var idx = existingCount.length;
      for (final songId in songIds) {
        await into(playlistSongs).insert(
          PlaylistSongsCompanion.insert(
            playlistId: playlistId,
            songId: songId,
            position: Value(idx++),
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }
    });
  }

  Future<List<Song>> songsInPlaylistSortedByNorm(int playlistId) {
    final query = select(songs).join([
      innerJoin(playlistSongs, playlistSongs.songId.equalsExp(songs.id)),
    ]);
    query.where(playlistSongs.playlistId.equals(playlistId));
    query.orderBy([
      OrderingTerm.asc(songs.titleNorm),
      OrderingTerm.asc(songs.artistNorm),
    ]);
    return query.watch().first.then(
          (rows) => rows.map((row) => row.readTable(songs)).toList(),
        );
  }
}

class QueueItemWithSong {
  QueueItemWithSong({required this.item, required this.song});

  final QueueItem item;
  final Song song;
}

@DriftAccessor(tables: [QueueItems, Songs])
class QueueDao extends DatabaseAccessor<AppDatabase> with _$QueueDaoMixin {
  QueueDao(super.db);

  Stream<List<QueueItemWithSong>> queueItemsWithSongs(int playlistId) {
    final query = select(queueItems).join([
      innerJoin(songs, songs.id.equalsExp(queueItems.songId)),
    ]);
    query.where(queueItems.playlistId.equals(playlistId));
    query.orderBy([OrderingTerm.asc(queueItems.position)]);
    return query.watch().map((rows) {
      return rows
          .map((row) => QueueItemWithSong(
                item: row.readTable(queueItems),
                song: row.readTable(songs),
              ))
          .toList();
    });
  }

  Future<int> enqueue(int playlistId, int songId, int position) {
    return into(queueItems).insert(
      QueueItemsCompanion.insert(
        playlistId: playlistId,
        songId: songId,
        position: Value(position),
      ),
    );
  }

  Future<void> reorderQueue(int playlistId, List<int> itemIdsInOrder) async {
    await transaction(() async {
      for (var i = 0; i < itemIdsInOrder.length; i++) {
        final id = itemIdsInOrder[i];
        await (update(queueItems)
              ..where((t) => t.id.equals(id) & t.playlistId.equals(playlistId)))
            .write(QueueItemsCompanion(position: Value(i)));
      }
    });
  }

  Future<void> removeQueueItem(int id) async {
    await (delete(queueItems)..where((t) => t.id.equals(id))).go();
  }

  Future<void> clearQueue(int playlistId) async {
    await (delete(queueItems)..where((t) => t.playlistId.equals(playlistId))).go();
  }
}
