class FuriganaSegment {
  const FuriganaSegment(this.text, {this.reading});

  final String text;
  final String? reading;

  bool get hasReading => reading != null;
}

class LyricsDisplayLine {
  const LyricsDisplayLine({
    required this.segments,
    required this.translation,
  });

  final List<FuriganaSegment> segments;
  final String translation;
}

class LyricsFormatException implements Exception {
  const LyricsFormatException({
    required this.line,
    required this.column,
    required this.message,
  });

  final int line;
  final int column;
  final String message;

  @override
  String toString() => '第 $line 行，第 $column 列：$message';
}

class FuriganaParser {
  const FuriganaParser();

  List<FuriganaSegment> parseLine(String source, {int lineNumber = 1}) {
    final segments = <FuriganaSegment>[];
    final plainText = StringBuffer();

    void flushPlainText() {
      if (plainText.isEmpty) return;
      segments.add(FuriganaSegment(plainText.toString()));
      plainText.clear();
    }

    var index = 0;
    while (index < source.length) {
      final character = source[index];
      if (character == ']') {
        throw LyricsFormatException(
          line: lineNumber,
          column: index + 1,
          message: '发现多余的右方括号 “]”',
        );
      }
      if (character != '[') {
        plainText.write(character);
        index++;
        continue;
      }

      flushPlainText();
      final closingBracket = source.indexOf(']', index + 1);
      if (closingBracket < 0) {
        throw LyricsFormatException(
          line: lineNumber,
          column: index + 1,
          message: '注音标记缺少右方括号 “]”',
        );
      }

      final marker = source.substring(index + 1, closingBracket);
      if (marker.contains('[')) {
        throw LyricsFormatException(
          line: lineNumber,
          column: index + 1,
          message: '注音标记中不能嵌套左方括号',
        );
      }
      final separator = marker.indexOf('|');
      if (separator < 0) {
        throw LyricsFormatException(
          line: lineNumber,
          column: index + 1,
          message: '注音标记缺少分隔符 “|”，正确格式为 [汉字|平假名]',
        );
      }
      if (marker.indexOf('|', separator + 1) >= 0) {
        throw LyricsFormatException(
          line: lineNumber,
          column: index + separator + 2,
          message: '一个注音标记只能包含一个分隔符 “|”',
        );
      }

      final text = marker.substring(0, separator);
      final reading = marker.substring(separator + 1);
      if (text.isEmpty) {
        throw LyricsFormatException(
          line: lineNumber,
          column: index + 2,
          message: '“|” 前的文字不能为空',
        );
      }
      if (reading.isEmpty) {
        throw LyricsFormatException(
          line: lineNumber,
          column: index + separator + 3,
          message: '“|” 后的读音不能为空',
        );
      }

      segments.add(FuriganaSegment(text, reading: reading));
      index = closingBracket + 1;
    }

    flushPlainText();
    return segments;
  }

  List<List<FuriganaSegment>> parse(String source) {
    final lines = source.split('\n');
    return [
      for (var index = 0; index < lines.length; index++)
        parseLine(lines[index], lineNumber: index + 1),
    ];
  }

  List<LyricsDisplayLine> parseDocument({
    required String japanese,
    required String translation,
  }) {
    final japaneseLines = parse(japanese);
    final translationLines = translation.split('\n');
    final lineCount = japaneseLines.length > translationLines.length
        ? japaneseLines.length
        : translationLines.length;

    return [
      for (var index = 0; index < lineCount; index++)
        LyricsDisplayLine(
          segments: index < japaneseLines.length
              ? japaneseLines[index]
              : const <FuriganaSegment>[],
          translation:
              index < translationLines.length ? translationLines[index] : '',
        ),
    ];
  }

  LyricsFormatException? validate(String source) {
    try {
      parse(source);
      return null;
    } on LyricsFormatException catch (error) {
      return error;
    }
  }
}
