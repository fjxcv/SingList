class LyricAiPrompt {
  const LyricAiPrompt._();

  static List<Map<String, String>> messages({
    required String title,
    required String artist,
    required String rawLyrics,
  }) {
    final numbered = rawLyrics
        .split('\n')
        .asMap()
        .entries
        .map((entry) => '${entry.key}: ${entry.value}')
        .join('\n');
    return [
      const {
        'role': 'system',
        'content': '''
You faithfully format user-provided song lyrics. Never search, invent, complete,
remove, merge, reorder, censor, or paraphrase lyric lines. Return JSON only:
{"language":"ja","lines":[{"index":0,"display":"","translation":""}],"warnings":[]}
Every input line, including empty lines and repeated choruses, must have exactly
one item with the same index. Do not repeat the original text in the JSON.
For Japanese, display uses [漢字|ひらがな] only where kanji needs furigana.
The separator MUST be the ASCII vertical bar "|" (U+007C). Never use slash
"/", full-width slash "／", or full-width vertical bar "｜". Example:
[雨|あめ]が[降|ふ]った. Before returning JSON, verify that every furigana
marker contains exactly one ASCII "|" and has a closing bracket.
Keep kana, katakana, Latin text, numbers and punctuation unchanged. Readings
must be hiragana, never romaji. For every non-empty Japanese line, translation
must contain a faithful, natural Simplified Chinese translation. Never leave a
Japanese translation empty, including repeated lines and short interjections.
Put uncertainty in warnings.
For other languages, display is the cleaned but faithful original line.
Translation is line-aligned Simplified Chinese for every non-empty line. Only
lines that are already Chinese or whose original text is empty may have an empty
translation. Do not put translation inside display. No Markdown or extra prose.
''',
      },
      {
        'role': 'user',
        'content': '''
Song title: $title
Artist: $artist
Process only the following numbered lines:
$numbered
''',
      },
    ];
  }
}
