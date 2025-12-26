String normalizeText(String input) {
  final collapsed = input.trim().replaceAll(RegExp(r'\s+'), ' ');
  return collapsed.toLowerCase();
}

String normalizeTitle(String title) => normalizeText(title);
String normalizeArtist(String artist) => normalizeText(artist);
