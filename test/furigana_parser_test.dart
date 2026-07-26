import 'package:flutter_test/flutter_test.dart';
import 'package:sing_list/lyrics/furigana_parser.dart';

void main() {
  const parser = FuriganaParser();

  group('FuriganaParser', () {
    test('parses a single furigana marker', () {
      final segments = parser.parseLine('[未熟|みじゅく]');

      expect(segments, hasLength(1));
      expect(segments.single.text, '未熟');
      expect(segments.single.reading, 'みじゅく');
    });

    test('parses multiple markers in one line', () {
      final segments = parser.parseLine('[未熟|みじゅく]、[無常|むじょう]されど');

      expect(segments.map((segment) => segment.text), [
        '未熟',
        '、',
        '無常',
        'されど',
      ]);
      expect(segments.where((segment) => segment.hasReading), hasLength(2));
    });

    test('keeps kana, kanji and punctuation outside markers as plain text', () {
      final segments = parser.parseLine('僕は[美|うつく]しく、ある。');

      expect(segments.map((segment) => segment.text), ['僕は', '美', 'しく、ある。']);
      expect(segments[1].reading, 'うつく');
    });

    test('accepts ordinary text without furigana', () {
      final segments = parser.parseLine('ひらがなと普通の文字。');

      expect(segments, hasLength(1));
      expect(segments.single.text, 'ひらがなと普通の文字。');
      expect(segments.single.reading, isNull);
    });

    test('preserves empty lines and multiple lines', () {
      final lines = parser.parse('[空|そら]\n\n青い');

      expect(lines, hasLength(3));
      expect(lines[0].single.reading, 'そら');
      expect(lines[1], isEmpty);
      expect(lines[2].single.text, '青い');
    });

    test('reports malformed markers with a useful location', () {
      final cases = <String>[
        '[未熟みじゅく]',
        '[未熟|みじゅく',
        '未熟]',
        '[|みじゅく]',
        '[未熟|]',
        '[未熟|みじゅく|別]',
      ];

      for (final source in cases) {
        final error = parser.validate(source);
        expect(error, isNotNull, reason: source);
        expect(error.toString(), contains('第 1 行'), reason: source);
      }
    });

    test('aligns when translations have fewer lines', () {
      final lines = parser.parseDocument(
        japanese: '一\n二\n三',
        translation: '壹',
      );

      expect(lines, hasLength(3));
      expect(lines.map((line) => line.translation), ['壹', '', '']);
    });

    test('keeps extra translation lines', () {
      final lines = parser.parseDocument(
        japanese: '一',
        translation: '壹\n额外',
      );

      expect(lines, hasLength(2));
      expect(lines[1].segments, isEmpty);
      expect(lines[1].translation, '额外');
    });
  });
}
