import 'package:flutter_test/flutter_test.dart';
import 'package:sing_list/service/import_parser.dart';

void main() {
  test('parseImportText handles headers, blanks and error lines', () {
    const text = '#K歌歌单\nSong A - Artist A\n\nSong B/Artist B\nSong C — Artist C\nInvalid Line\nNoArtist -\n/NoTitle';
    final result = parseImportText(text);
    expect(result.songs.length, 3);
    expect(result.songs[0].title, 'Song A');
    expect(result.songs[1].artist, 'Artist B');
    expect(result.songs[2].title, 'Song C');
    expect(result.errorLines, containsAll(['Invalid Line', 'NoArtist -', '/NoTitle']));
  });

  test('parseImportText keeps duplicate entries', () {
    const text = 'Song A - Artist A\nSong A - Artist A';
    final result = parseImportText(text);
    expect(result.songs.length, 2);
    expect(result.errorLines, isEmpty);
  });
}
