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
    String? originalText,
    String? languageCode,
    String? sourceName,
    String? sourceUrl,
    String? versionLabel,
    String? aiProvider,
    String? aiModel,
    bool? wasManuallyEdited,
  }) {
    return db.lyricsDao.save(
      songId: songId,
      japanese: japanese,
      translation: translation,
      originalText: originalText,
      languageCode: languageCode,
      sourceName: sourceName,
      sourceUrl: sourceUrl,
      versionLabel: versionLabel,
      aiProvider: aiProvider,
      aiModel: aiModel,
      wasManuallyEdited: wasManuallyEdited,
    );
  }

  Future<void> deleteForSong(int songId) {
    return db.lyricsDao.deleteForSong(songId);
  }
}
