import 'package:flutter/material.dart';

import '../../lyrics/furigana_parser.dart';

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
                    crossAxisAlignment: WrapCrossAlignment.end,
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
                            Text(
                              String.fromCharCode(rune),
                              style: TextStyle(
                                fontSize: fontSize,
                                height: 1.65,
                                color: foreground,
                              ),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            reading,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: fontSize * 0.46,
              height: 1.05,
              color: color,
            ),
          ),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: fontSize, height: 1.12, color: color),
          ),
        ],
      ),
    );
  }
}
