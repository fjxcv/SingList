class ProcessedLyricLine {
  const ProcessedLyricLine({
    required this.index,
    required this.original,
    required this.display,
    required this.translation,
  });

  final int index;
  final String original;
  final String display;
  final String translation;
}

class LyricProcessingResult {
  const LyricProcessingResult({
    required this.language,
    required this.lines,
    required this.warnings,
    required this.actualModel,
  });

  final String language;
  final List<ProcessedLyricLine> lines;
  final List<String> warnings;
  final String actualModel;

  String get originalText => lines.map((line) => line.original).join('\n');
  String get displayText => lines.map((line) => line.display).join('\n');
  String get translationText =>
      lines.map((line) => line.translation).join('\n');
}
