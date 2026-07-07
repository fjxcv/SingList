bool matchesSongKeyword({
  required String titleNorm,
  required String artistNorm,
  required String keyword,
}) {
  final normalized = normalizeText(keyword);
  if (normalized.isEmpty) return true;
  return titleNorm.contains(normalized) || artistNorm.contains(normalized);
}

String normalizeText(String input) {
  final collapsed = input.trim().replaceAll(RegExp(r'\s+'), ' ');
  return collapsed.toLowerCase();
}

String normalizeTitle(String title) => normalizeText(title);
String normalizeArtist(String artist) => normalizeText(artist);
