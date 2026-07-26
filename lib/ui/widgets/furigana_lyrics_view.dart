import 'package:flutter/material.dart';

import '../../lyrics/furigana_parser.dart';

const _japaneseLocale = Locale('ja');
const _japaneseFontFallback = <String>[
  'Noto Sans JP',
  'Noto Sans CJK JP',
  'Yu Gothic',
  'Meiryo',
  'sans-serif',
];

class FuriganaLyricsView extends StatelessWidget {
  const FuriganaLyricsView({
    super.key,
    required this.japanese,
    required this.translation,
    required this.fontSize,
    required this.showTranslation,
    this.textColor,
    this.translationColor,
  });

  final String japanese;
  final String translation;
  final double fontSize;
  final bool showTranslation;
  final Color? textColor;
  final Color? translationColor;

  @override
  Widget build(BuildContext context) {
    final lines = const FuriganaParser().parseDocument(
      japanese: japanese,
      translation: translation,
    );
    final foreground = textColor ?? Theme.of(context).colorScheme.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final line in lines)
          Padding(
            padding: EdgeInsets.only(bottom: fontSize * 0.8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (line.segments.isEmpty)
                  SizedBox(height: fontSize * 1.65)
                else
                  Wrap(
                    runSpacing: fontSize * 0.28,
                    crossAxisAlignment: WrapCrossAlignment.start,
                    children: [
                      for (final segment in line.segments)
                        if (segment.hasReading)
                          _RubyText(
                            text: segment.text,
                            reading: segment.reading!,
                            fontSize: fontSize,
                            color: foreground,
                          )
                        else
                          for (final rune in segment.text.runes)
                            _PlainJapaneseText(
                              text: String.fromCharCode(rune),
                              fontSize: fontSize,
                              color: foreground,
                            ),
                    ],
                  ),
                if (showTranslation && line.translation.isNotEmpty) ...[
                  SizedBox(height: fontSize * 0.15),
                  Text(
                    line.translation,
                    style: TextStyle(
                      fontSize: fontSize * 0.62,
                      height: 1.45,
                      color: translationColor ??
                          Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _PlainJapaneseText extends StatelessWidget {
  const _PlainJapaneseText({
    required this.text,
    required this.fontSize,
    required this.color,
  });

  final String text;
  final double fontSize;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: fontSize * 0.5),
      child: Text(
        text,
        locale: _japaneseLocale,
        style: TextStyle(
          fontSize: fontSize,
          height: 1.12,
          fontWeight: FontWeight.w400,
          fontFamilyFallback: _japaneseFontFallback,
          color: color,
        ),
      ),
    );
  }
}

class _RubyText extends StatelessWidget {
  const _RubyText({
    required this.text,
    required this.reading,
    required this.fontSize,
    required this.color,
  });

  final String text;
  final String reading;
  final double fontSize;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      // Keep each ruby group only as wide as its own text. Otherwise a Column
      // can expand to the Wrap's full width and center the kanji on a new line.
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                height: fontSize * 0.5,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Text(
                    reading,
                    locale: _japaneseLocale,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: fontSize * 0.42,
                      height: 1,
                      fontWeight: FontWeight.w400,
                      fontFamilyFallback: _japaneseFontFallback,
                      color: color,
                    ),
                  ),
                ),
              ),
              Text(
                text,
                locale: _japaneseLocale,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: fontSize,
                  height: 1.12,
                  fontWeight: FontWeight.w400,
                  fontFamilyFallback: _japaneseFontFallback,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
