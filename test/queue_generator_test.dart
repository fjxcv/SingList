import 'package:flutter_test/flutter_test.dart';
import 'package:sing_list/data/db/app_database.dart';
import 'package:sing_list/service/queue_generator.dart';

Song fakeSong(int id) => Song(
      id: id,
      title: 'Song$id',
      artist: 'Artist$id',
      titleNorm: 'song$id',
      artistNorm: 'artist$id',
      createdAt: DateTime.now(),
    );

void main() {
  test('mergeBrushSelections orders warmup, favorites, likes', () {
    final selection = BrushSelection(
      warmups: [fakeSong(1)],
      favorites: [fakeSong(2), fakeSong(3)],
      likes: [fakeSong(4)],
    );
    final ordered = mergeBrushSelections(selection);
    expect(ordered.map((e) => e.id), [1, 2, 3, 4]);
  });
}
