import 'package:drift/drift.dart';

import '../data/db/app_database.dart';
import '../service/normalize.dart';

class SongRepository {
  final AppDatabase db;
  SongRepository(this.db);

  Future<int> addSong(String title, String artist) async {
    final titleNorm = normalizeTitle(title);
    final artistNorm = normalizeArtist(artist);
    return db.into(db.songs).insert(
          SongsCompanion.insert(
            title: title,
            artist: artist,
            titleNorm: titleNorm,
            artistNorm: artistNorm,
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  Future<void> updateSong(int id, String title, String artist) async {
    final titleNorm = normalizeTitle(title);
    final artistNorm = normalizeArtist(artist);
    await (db.update(db.songs)..where((tbl) => tbl.id.equals(id))).write(
      SongsCompanion(
        title: Value(title),
        artist: Value(artist),
        titleNorm: Value(titleNorm),
        artistNorm: Value(artistNorm),
      ),
    );
  }

  Future<void> deleteSong(int id) async {
    await db.transaction(() async {
      await (db.delete(db.songTags)..where((t) => t.songId.equals(id))).go();
      await (db.delete(db.queueItems)..where((t) => t.songId.equals(id))).go();
      await (db.delete(db.playlistEntries)..where((t) => t.songId.equals(id))).go();
      await (db.delete(db.songs)..where((t) => t.id.equals(id))).go();
    });
  }

  Stream<List<Song>> watchAll({String keyword = ''}) {
    final query = (db.select(db.songs)
      ..orderBy([(s) => OrderingTerm.desc(s.createdAt)]));
    if (keyword.trim().isNotEmpty) {
      final like = '%${keyword.trim()}%';
      query.where((tbl) => tbl.title.like(like) | tbl.artist.like(like));
    }
    return query.watch();
  }

  Future<List<Song>> search(String keyword) {
    final like = '%${keyword.trim()}%';
    return (db.select(db.songs)
          ..where((tbl) => tbl.title.like(like) | tbl.artist.like(like)))
        .get();
  }
}
