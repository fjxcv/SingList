import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sing_list/ui/widgets/furigana_lyrics_view.dart';

void main() {
  testWidgets('places the reading above its matching kanji', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FuriganaLyricsView(
            japanese: '[未熟|みじゅく]されど[美|うつく]しくあれ',
            translation: '虽不成熟，也要活得美丽',
            fontSize: 28,
            showTranslation: true,
          ),
        ),
      ),
    );

    final readingTop = tester.getTopLeft(find.text('みじゅく')).dy;
    final kanjiTop = tester.getTopLeft(find.text('未熟')).dy;

    expect(readingTop, lessThan(kanjiTop));
    expect(find.text('虽不成熟，也要活得美丽'), findsOneWidget);
  });

  testWidgets('keeps annotated kanji inline with adjacent kana',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FuriganaLyricsView(
            japanese: '[雨|あめ]が[降|ふ]った',
            translation: '下雨了',
            fontSize: 28,
            showTranslation: true,
          ),
        ),
      ),
    );

    final rainCenter = tester.getCenter(find.text('雨'));
    final gaCenter = tester.getCenter(find.text('が'));
    final fallCenter = tester.getCenter(find.text('降'));
    final smallTsuCenter = tester.getCenter(find.text('っ'));

    expect(gaCenter.dx, greaterThan(rainCenter.dx));
    expect(fallCenter.dx, greaterThan(gaCenter.dx));
    expect(smallTsuCenter.dx, greaterThan(fallCenter.dx));
    expect((gaCenter.dy - rainCenter.dy).abs(), lessThan(2));
    expect((fallCenter.dy - rainCenter.dy).abs(), lessThan(2));
    expect((smallTsuCenter.dy - rainCenter.dy).abs(), lessThan(2));
  });

  testWidgets('centers every reading over only its matching kanji',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FuriganaLyricsView(
            japanese: '[雨|あめ]が[降|ふ]った [花|はな]は[散|ち]った',
            translation: '下雨了，花凋谢了',
            fontSize: 28,
            showTranslation: true,
          ),
        ),
      ),
    );

    for (final pair in <(String, String)>[
      ('雨', 'あめ'),
      ('降', 'ふ'),
      ('花', 'はな'),
      ('散', 'ち'),
    ]) {
      final kanjiRect = tester.getRect(find.text(pair.$1));
      final readingRect = tester.getRect(find.text(pair.$2));

      expect(readingRect.bottom, lessThanOrEqualTo(kanjiRect.top + 1));
      expect(
        (readingRect.center.dx - kanjiRect.center.dx).abs(),
        lessThan(1),
      );
    }

    final baseLineY = tester.getCenter(find.text('雨')).dy;
    for (final text in <String>['降', '花', '散']) {
      expect(
        (tester.getCenter(find.text(text)).dy - baseLineY).abs(),
        lessThan(2),
      );
    }
  });

  testWidgets('can hide the Chinese translation', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FuriganaLyricsView(
            japanese: '[空|そら]',
            translation: '天空',
            fontSize: 28,
            showTranslation: false,
          ),
        ),
      ),
    );

    expect(find.text('そら'), findsOneWidget);
    expect(find.text('空'), findsOneWidget);
    expect(find.text('天空'), findsNothing);
  });
}
