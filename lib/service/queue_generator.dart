import 'dart:math';

import '../data/db/app_database.dart';

class BrushSelection {
  final List<Song> favorites;
  final List<Song> likes;
  final List<Song> warmups;
  BrushSelection({this.favorites = const [], this.likes = const [], this.warmups = const []});
}

List<Song> mergeBrushSelections(BrushSelection selection) {
  final result = <Song>[];
  result.addAll(selection.warmups);
  result.addAll(selection.favorites);
  result.addAll(selection.likes);
  return result;
}

List<Song> pickRandomSongs(List<Song> source, int count, {bool avoidRepeat = true}) {
  return pickWithoutConsecutiveRepeat(
    source,
    count,
    allowRepeat: !avoidRepeat,
  );
}

/// Picks [count] songs from [pool], avoiding adjacent duplicates.
/// When [allowRepeat] is false, each song appears at most once.
List<Song> pickWithoutConsecutiveRepeat(
  List<Song> pool,
  int count, {
  int? lastSongId,
  bool allowRepeat = true,
  Random? random,
}) {
  if (pool.isEmpty || count <= 0) return [];
  final rng = random ?? Random();

  if (!allowRepeat) {
    final shuffled = List<Song>.from(pool)..shuffle(rng);
    final takeCount = min(count, shuffled.length);
    final result = shuffled.take(takeCount).toList();
    return avoidConsecutiveBoundary(result, lastSongId: lastSongId);
  }

  return _pickWithSpacing(pool, count, lastSongId: lastSongId, rng: rng);
}

List<Song> _pickWithSpacing(
  List<Song> candidates,
  int desiredCount, {
  int? lastSongId,
  required Random rng,
}) {
  final result = <Song>[];
  final lastIndex = <int, int>{};
  int? previousId = lastSongId;
  for (var i = 0; i < desiredCount; i++) {
    final eligible = candidates.where((song) => song.id != previousId).toList();
    final pool = eligible.isEmpty ? candidates : eligible;
    Song? best;
    var bestScore = -1;
    for (final song in pool) {
      final last = lastIndex[song.id];
      final score = last == null ? 100000 + rng.nextInt(100) : i - last;
      if (score > bestScore) {
        bestScore = score;
        best = song;
      } else if (score == bestScore && rng.nextBool()) {
        best = song;
      }
    }
    final picked = best ?? pool[rng.nextInt(pool.length)];
    result.add(picked);
    lastIndex[picked.id] = i;
    previousId = picked.id;
  }
  return result;
}

/// If the first picked song matches [lastSongId], swap with a later different song.
List<Song> avoidConsecutiveBoundary(
  List<Song> songs, {
  int? lastSongId,
}) {
  if (lastSongId == null || songs.isEmpty || songs.first.id != lastSongId) {
    return songs;
  }
  final result = List<Song>.from(songs);
  for (var i = 1; i < result.length; i++) {
    if (result[i].id != lastSongId) {
      final temp = result[0];
      result[0] = result[i];
      result[i] = temp;
      break;
    }
  }
  return result;
}

/// Swaps the first item of [second] if it duplicates the last item of [first].
List<Song> avoidSegmentBoundary(List<Song> first, List<Song> second) {
  if (first.isEmpty || second.isEmpty) return second;
  final lastId = first.last.id;
  if (second.first.id != lastId) return second;
  final result = List<Song>.from(second);
  for (var i = 1; i < result.length; i++) {
    if (result[i].id != lastId) {
      final temp = result[0];
      result[0] = result[i];
      result[i] = temp;
      break;
    }
  }
  return result;
}
