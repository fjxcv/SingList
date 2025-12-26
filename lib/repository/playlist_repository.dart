import 'package:drift/drift.dart';

import '../data/db/app_database.dart';

class PlaylistRepository {
  final AppDatabase db;
  PlaylistRepository(this.db);

  Stream<List<Playlist>> watchByType(PlaylistType type) {
    return (db.select(db.playlists)..where((tbl) => tbl.type.equalsValue(type))
          ..orderBy([(p) => OrderingTerm.desc(p.createdAt)])).
        watch();
  }

  Future<int> create(String name, PlaylistType type) async {
    return db.into(db.playlists).insert(PlaylistsCompanion.insert(name: name, type: type));
  }

  Future<void> delete(int id) async {
    await db.transaction(() async {
      await (db.delete(db.playlistEntries)..where((t) => t.playlistId.equals(id))).go();
      await (db.delete(db.queueItems)..where((t) => t.playlistId.equals(id))).go();
      await (db.delete(db.playlists)..where((t) => t.id.equals(id))).go();
    });
  }

  Stream<List<Song>> songsInPlaylist(int playlistId) {
    final query = db.select(db.songs).join([
      innerJoin(db.playlistEntries, db.playlistEntries.songId.equalsExp(db.songs.id)),
    ]);
    query.where(db.playlistEntries.playlistId.equals(playlistId));
    query.orderBy([OrderingTerm.asc(db.playlistEntries.position)]);
    return query.watch().map((rows) => rows.map((r) => r.readTable(db.songs)).toList());
  }

  Future<void> addSongsToPlaylist(int playlistId, List<int> songIds) async {
    int idx = 0;
    for (final songId in songIds) {
      await db.into(db.playlistEntries).insert(
            PlaylistEntriesCompanion.insert(
              playlistId: playlistId,
              songId: songId,
              position: Value(idx++),
            ),
            mode: InsertMode.insertOrIgnore,
          );
    }
  }

  Stream<List<QueueItemWithSong>> queueItems(int playlistId) {
    final query = db.select(db.queueItems).join([
      innerJoin(db.songs, db.songs.id.equalsExp(db.queueItems.songId)),
    ]);
    query.where(db.queueItems.playlistId.equals(playlistId));
    query.orderBy([OrderingTerm.asc(db.queueItems.position)]);
    return query.watch().map((rows) {
      return rows
          .map(
            (row) => QueueItemWithSong(
              item: row.readTable(db.queueItems),
              song: row.readTable(db.songs),
            ),
          )
          .toList();
    });
  }

  Future<int> enqueue(int playlistId, int songId, int position) {
    return db.into(db.queueItems).insert(
          QueueItemsCompanion.insert(playlistId: playlistId, songId: songId, position: Value(position)),
        );
  }

  Future<void> reorderQueue(int playlistId, List<int> itemIdsInOrder) async {
    await db.transaction(() async {
      for (var i = 0; i < itemIdsInOrder.length; i++) {
        final id = itemIdsInOrder[i];
        await (db.update(db.queueItems)..where((t) => t.id.equals(id))).write(QueueItemsCompanion(position: Value(i)));
      }
    });
  }

  Future<void> removeQueueItem(int id) async {
    await (db.delete(db.queueItems)..where((t) => t.id.equals(id))).go();
  }

  Future<void> clearQueue(int playlistId) async {
    await (db.delete(db.queueItems)..where((t) => t.playlistId.equals(playlistId))).go();
  }
}

class QueueItemWithSong {
  final QueueItem item;
  final Song song;
  QueueItemWithSong({required this.item, required this.song});
}
