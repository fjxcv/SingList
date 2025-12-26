import '../repository/playlist_repository.dart';
import '../repository/song_repository.dart';
import 'import_parser.dart';

class KQueueImportResult {
  final Playlist playlist;
  final List<String> errorLines;

  KQueueImportResult({required this.playlist, required this.errorLines});
}

class KQueueTextService {
  final SongRepository songRepository;
  final PlaylistRepository playlistRepository;

  KQueueTextService(this.songRepository, this.playlistRepository);

  Future<String> exportQueueAsText(int playlistId, {bool includeTitle = true}) async {
    final items = await playlistRepository.queueItems(playlistId).first;
    final buffer = StringBuffer();
    if (includeTitle) {
      buffer.writeln('#K歌歌单');
    }
    for (final row in items) {
      buffer.writeln('${row.song.title} - ${row.song.artist}');
    }
    return buffer.toString();
  }

  Future<KQueueImportResult> importFromText(String raw) async {
    final parsed = parseImportText(raw);
    final songIds = <int>[];
    for (final song in parsed.songs) {
      final id = await songRepository.upsertByTitleArtist(song.title, song.artist);
      songIds.add(id);
    }
    if (songIds.isEmpty) {
      throw Exception('未能解析到有效的歌曲');
    }
    final playlist = await playlistRepository.createQueueWithSongs(songIds);
    return KQueueImportResult(playlist: playlist, errorLines: parsed.errorLines);
  }
}
