import 'normalize.dart';

class ParsedSong {
  final String title;
  final String artist;
  ParsedSong(this.title, this.artist);
}

class ParseResult {
  final List<ParsedSong> songs;
  final List<String> errorLines;
  ParseResult({required this.songs, required this.errorLines});
}

ParseResult parseImportText(String raw) {
  final lines = raw.split(RegExp(r'\r?\n'));
  final songs = <ParsedSong>[];
  final errorLines = <String>[];
  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final normalized = trimmed.replaceAll(RegExp(r'[—–]'), '-');
    String? title;
    String? artist;
    final dashPattern = RegExp(r'\s*-\s*');
    if (normalized.contains(' - ')) {
      final idx = normalized.indexOf(' - ');
      title = normalized.substring(0, idx);
      artist = normalized.substring(idx + 3);
    } else if (dashPattern.hasMatch(normalized) && normalized.contains('-')) {
      final parts = normalized.split(dashPattern);
      if (parts.length >= 2) {
        title = parts.first;
        artist = parts.sublist(1).join(' - ');
      }
    } else if (normalized.contains('/')) {
      final idx = normalized.indexOf('/');
      title = normalized.substring(0, idx);
      artist = normalized.substring(idx + 1);
    }
    if (title != null && artist != null) {
      final t = title.trim();
      final a = artist.trim();
      if (t.isNotEmpty && a.isNotEmpty) {
        songs.add(ParsedSong(t, a));
        continue;
      }
    }
    errorLines.add(trimmed);
  }
  return ParseResult(songs: songs, errorLines: errorLines);
}

class NormalizedSongKey {
  final String titleNorm;
  final String artistNorm;
  NormalizedSongKey(String title, String artist)
      : titleNorm = normalizeTitle(title),
        artistNorm = normalizeArtist(artist);
}
