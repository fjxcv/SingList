class LyricCandidate {
  const LyricCandidate({
    required this.id,
    required this.trackName,
    required this.artistName,
    required this.lyrics,
    required this.instrumental,
    this.albumName,
    this.durationSeconds,
  });

  final int id;
  final String trackName;
  final String artistName;
  final String? albumName;
  final double? durationSeconds;
  final bool instrumental;
  final String lyrics;

  String get sourceName => 'LRCLIB';
  String get sourceUrl => 'https://lrclib.net/api/get/$id';

  List<String> get previewLines => lyrics
      .split('\n')
      .where((line) => line.trim().isNotEmpty)
      .take(4)
      .toList();
}
