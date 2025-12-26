import 'package:flutter_test/flutter_test.dart';
import 'package:sing_list/service/import_parser.dart';

void main() {
  test('parseImportText handles multiple formats', () {
    const text = '#K歌歌单\nSong A - Artist A\nSong B/Artist B\n';
    final items = parseImportText(text);
    expect(items.length, 2);
    expect(items.first.title, 'Song A');
    expect(items.first.artist, 'Artist A');
    expect(items.last.title, 'Song B');
  });
}
