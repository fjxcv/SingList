import 'dart:math';

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

  test('pickWithoutConsecutiveRepeat avoids adjacent duplicates when repeating', () {
    final pool = [fakeSong(1), fakeSong(2)];
    final rng = _FixedRandom([0, 0, 1, 0, 1]);
    final result = pickWithoutConsecutiveRepeat(
      pool,
      6,
      allowRepeat: true,
      random: rng,
    );
    for (var i = 1; i < result.length; i++) {
      expect(result[i].id, isNot(result[i - 1].id));
    }
  });

  test('avoidConsecutiveBoundary swaps first when matching lastSongId', () {
    final songs = [fakeSong(1), fakeSong(2), fakeSong(3)];
    final adjusted = avoidConsecutiveBoundary(songs, lastSongId: 1);
    expect(adjusted.first.id, isNot(1));
  });

  test('avoidSegmentBoundary fixes warmup-to-main boundary', () {
    final warmups = [fakeSong(1), fakeSong(2)];
    final main = [fakeSong(2), fakeSong(3), fakeSong(1)];
    final adjusted = avoidSegmentBoundary(warmups, main);
    expect(adjusted.first.id, isNot(2));
  });

  test('pickWithoutConsecutiveRepeat deduplicates when allowRepeat is false', () {
    final pool = List.generate(5, fakeSong);
    final result = pickWithoutConsecutiveRepeat(
      pool,
      5,
      allowRepeat: false,
      random: Random(42),
    );
    expect(result.map((s) => s.id).toSet().length, 5);
  });
}

class _FixedRandom implements Random {
  _FixedRandom(this._values);

  final List<int> _values;
  var _index = 0;

  @override
  bool nextBool() => nextInt(2) == 0;

  @override
  double nextDouble() => nextInt(100) / 100;

  @override
  int nextInt(int max) {
    if (_index >= _values.length) return 0;
    return _values[_index++] % max;
  }
}
