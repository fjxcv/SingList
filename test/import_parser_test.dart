import 'package:flutter_test/flutter_test.dart';
import 'package:sing_list/service/import_parser.dart';

void main() {
  test('parseImportText handles headers, blanks and error lines', () {
    const text = '#header\nSong A - Artist A\n\nSong B/Artist B\nInvalid Line\nNoArtist -\n/NoTitle';
    final result = parseImportText(text);
    expect(result.songs.length, 2);
    expect(result.songs[0].title, 'Song A');
    expect(result.songs[1].artist, 'Artist B');
    expect(result.errorLines, containsAll(['Invalid Line', 'NoArtist -', '/NoTitle']));
  });

  test('parseImportContent parses csv', () {
    const csv = 'title,artist\nSong A,Artist A\nSong B - Artist B';
    final result = parseImportContent(csv, filename: 'songs.csv');
    expect(result.songs.length, 2);
    expect(result.songs[0].title, 'Song A');
    expect(result.songs[1].artist, 'Artist B');
  });

  test('parseImportText keeps duplicate entries', () {
    const text = 'Song A - Artist A\nSong A - Artist A';
    final result = parseImportText(text);
    expect(result.songs.length, 2);
    expect(result.errorLines, isEmpty);
  });
}
