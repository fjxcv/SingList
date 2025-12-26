import 'normalize.dart';

class ParsedSong {
  final String title;
  final String artist;
  ParsedSong(this.title, this.artist);
}

List<ParsedSong> parseImportText(String raw) {
  final lines = raw.split(RegExp(r'\r?\n'));
  final items = <ParsedSong>[];
  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final normalized = trimmed.replaceAll('—', '-');
    String? title;
    String? artist;
    if (normalized.contains(' - ')) {
      final parts = normalized.split(' - ');
      if (parts.length >= 2) {
        title = parts[0];
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
        items.add(ParsedSong(t, a));
      }
    }
  }
  return items;
}

class NormalizedSongKey {
  final String titleNorm;
  final String artistNorm;
  NormalizedSongKey(String title, String artist)
      : titleNorm = normalizeTitle(title),
        artistNorm = normalizeArtist(artist);
}
