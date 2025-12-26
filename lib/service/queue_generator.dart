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
  final rng = Random();
  final list = List<Song>.from(source);
  final picked = <Song>[];
  while (picked.length < count && list.isNotEmpty) {
    final idx = rng.nextInt(list.length);
    picked.add(list[idx]);
    if (avoidRepeat) {
      list.removeAt(idx);
    }
  }
  return picked;
}
