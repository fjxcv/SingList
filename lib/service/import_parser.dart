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
    final normalized = trimmed.replaceAll(RegExp(r'[���C]'), '-');
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
    } else if (normalized.contains(',')) {
      final idx = normalized.indexOf(',');
      title = normalized.substring(0, idx);
      artist = normalized.substring(idx + 1);
    } else if (normalized.contains('��')) {
      final idx = normalized.indexOf('��');
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

ParseResult parseImportContent(String raw, {String? filename}) {
  final lower = filename?.toLowerCase() ?? '';
  if (lower.endsWith('.csv')) {
    return _parseCsv(raw);
  }
  return parseImportText(raw);
}

ParseResult _parseCsv(String raw) {
  final lines = raw.split(RegExp(r'\r?\n'));
  final songs = <ParsedSong>[];
  final errorLines = <String>[];
  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;
    if (trimmed.toLowerCase().startsWith('title') && trimmed.contains(',')) continue;
    ParsedSong? parsed;
    if (trimmed.contains(' - ')) {
      final idx = trimmed.indexOf(' - ');
      parsed = ParsedSong(trimmed.substring(0, idx).trim(), trimmed.substring(idx + 3).trim());
    } else {
      final parts = trimmed.split(',');
      if (parts.length >= 2) {
        parsed = ParsedSong(parts[0].trim(), parts.sublist(1).join(',').trim());
      }
    }
    if (parsed != null && parsed.title.isNotEmpty && parsed.artist.isNotEmpty) {
      songs.add(parsed);
    } else {
      errorLines.add(trimmed);
    }
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
