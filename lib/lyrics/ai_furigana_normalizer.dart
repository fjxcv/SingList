class AiFuriganaNormalizer {
  const AiFuriganaNormalizer();

  static final RegExp _markerPattern = RegExp(r'\[([^\[\]]+)\]');
  static final RegExp _kanjiPattern = RegExp(
    r'[\u3400-\u4DBF\u4E00-\u9FFF\uF900-\uFAFF々〆ヶ]',
  );
  static final RegExp _hiraganaReadingPattern = RegExp(
    r'^[\u3040-\u309Fー]+$',
  );
  static const _alternateSeparators = <String>['/', '／', '｜', '│'];

  String normalize(String source) {
    return source.replaceAllMapped(_markerPattern, (match) {
      final wholeMarker = match.group(0)!;
      final marker = match.group(1)!;
      if (marker.contains('|')) return wholeMarker;

      for (final separator in _alternateSeparators) {
        final first = marker.indexOf(separator);
        if (first < 0 || marker.indexOf(separator, first + 1) >= 0) {
          continue;
        }

        final text = marker.substring(0, first);
        final reading = marker.substring(first + separator.length);
        if (_kanjiPattern.hasMatch(text) &&
            _hiraganaReadingPattern.hasMatch(reading)) {
          return '[$text|$reading]';
        }
      }
      return wholeMarker;
    });
  }
}
