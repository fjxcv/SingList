import '../data/db/app_database.dart';

class LyricsRepository {
  LyricsRepository(this.db);

  final AppDatabase db;

  Stream<SongLyric?> watchForSong(int songId) {
    return db.lyricsDao.watchForSong(songId);
  }

  Future<SongLyric?> findForSong(int songId) {
    return db.lyricsDao.findForSong(songId);
  }

  Future<void> save({
    required int songId,
    required String japanese,
    required String translation,
  }) {
    return db.lyricsDao.save(
      songId: songId,
      japanese: japanese,
      translation: translation,
    );
  }

  Future<void> deleteForSong(int songId) {
    return db.lyricsDao.deleteForSong(songId);
  }
}
