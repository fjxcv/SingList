import 'dart:io';

void main() {
  File('lib/service/kqueue_text_service.dart').writeAsStringSync(r'''
import '../data/db/app_database.dart';
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
      buffer.writeln('#K\u6b4c\u6b4c\u5355');
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
      throw Exception('\u672a\u80fd\u89e3\u6790\u5230\u6709\u6548\u7684\u6b4c\u66f2');
    }
    final playlist = await playlistRepository.createQueueWithSongs(songIds);
    return KQueueImportResult(playlist: playlist, errorLines: parsed.errorLines);
  }
}
''');

  final header = '#K\u6b4c\u6b4c\u5355';
  final path = 'test/kqueue_text_service_test.dart';
  var text = File(path).readAsStringSync();
  text = text.replaceAllMapped(
    RegExp(r"importFromText\('.*?\\nHello - Singer"),
    (_) => "importFromText('$header\\nHello - Singer",
  );
  text = text.replaceAllMapped(
    RegExp(r"expect\(text\.trim\(\), '.*?\\nSong1"),
    (_) => "expect(text.trim(), '$header\\nSong1",
  );
  File(path).writeAsStringSync(text);
  print('kqueue files fixed');
}
