import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/app_database.dart';
import '../repository/playlist_repository.dart';
import '../repository/song_repository.dart';
import '../repository/tag_repository.dart';
import 'brush_generator_state.dart';
import 'providers.dart';

class RandomQueueState {
  const RandomQueueState({
    this.sourceType = BrushSourceType.all,
    this.selectedTagId,
    this.selectedPlaylistId,
    this.count = 15,
    this.avoidRepeat = true,
    this.warmupEnabled = true,
    this.warmupCount = 2,
    this.isLoading = false,
    this.error,
  });

  final BrushSourceType sourceType;
  final int? selectedTagId;
  final int? selectedPlaylistId;
  final int count;
  final bool avoidRepeat;
  final bool warmupEnabled;
  final int warmupCount;
  final bool isLoading;
  final String? error;

  RandomQueueState copyWith({
    BrushSourceType? sourceType,
    int? selectedTagId,
    int? selectedPlaylistId,
    int? count,
    bool? avoidRepeat,
    bool? warmupEnabled,
    int? warmupCount,
    bool? isLoading,
    String? error,
  }) {
    return RandomQueueState(
      sourceType: sourceType ?? this.sourceType,
      selectedTagId: selectedTagId ?? this.selectedTagId,
      selectedPlaylistId: selectedPlaylistId ?? this.selectedPlaylistId,
      count: count ?? this.count,
      avoidRepeat: avoidRepeat ?? this.avoidRepeat,
      warmupEnabled: warmupEnabled ?? this.warmupEnabled,
      warmupCount: warmupCount ?? this.warmupCount,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

final randomQueueProvider =
    AutoDisposeNotifierProvider<RandomQueueNotifier, RandomQueueState>(
  RandomQueueNotifier.new,
);

class RandomQueueNotifier extends AutoDisposeNotifier<RandomQueueState> {
  @override
  RandomQueueState build() {
    return const RandomQueueState();
  }

  void updateSourceType(BrushSourceType type) {
    state = state.copyWith(
      sourceType: type,
      selectedTagId: type == BrushSourceType.tag ? state.selectedTagId : null,
      selectedPlaylistId:
          type == BrushSourceType.playlist ? state.selectedPlaylistId : null,
      error: null,
    );
  }

  void updateTag(int? tagId) {
    state = state.copyWith(selectedTagId: tagId, error: null);
  }

  void updatePlaylist(int? playlistId) {
    state = state.copyWith(selectedPlaylistId: playlistId, error: null);
  }

  void updateCount(int count) {
    final clamped = count < 1
        ? 1
        : count > 100
            ? 100
            : count;
    state = state.copyWith(count: clamped, error: null);
  }

  void updateAvoidRepeat(bool value) {
    state = state.copyWith(avoidRepeat: value);
  }

  void updateWarmupEnabled(bool value) {
    state = state.copyWith(warmupEnabled: value);
  }

  void updateWarmupCount(int count) {
    final clamped = count < 0
        ? 0
        : count > 20
            ? 20
            : count;
    state = state.copyWith(warmupCount: clamped);
  }

  Future<Playlist?> generateQueue({bool? avoidRepeatOverride}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final candidates = await _loadSourceSongs();
      final avoidRepeat = avoidRepeatOverride ?? state.avoidRepeat;
      if (candidates.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          error: '请先选择有效来源',
        );
        return null;
      }

      final usedIds = <int>{};
      final warmups = await _pickWarmups(usedIds, avoidRepeat: avoidRepeat);
      if (avoidRepeat) {
        usedIds.addAll(warmups.map((e) => e.id));
      }

      final mainSongs = _pickSongs(
        candidates.where((s) => !usedIds.contains(s.id)).toList(),
        state.count,
        avoidRepeat: avoidRepeat,
        lastSongId: warmups.isNotEmpty ? warmups.last.id : null,
      );

      final all = [...warmups, ...mainSongs];
      if (all.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          error: '没有可用的歌曲生成 KQueue',
        );
        return null;
      }

      final queue = await ref.read(playlistRepoProvider).createQueueWithSongs(
            all.map((e) => e.id).toList(),
          );
      state = state.copyWith(isLoading: false);
      return queue;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '$e');
      return null;
    }
  }

  Future<List<Song>> _pickWarmups(
    Set<int> usedIds, {
    required bool avoidRepeat,
  }) async {
    if (!state.warmupEnabled || state.warmupCount <= 0) return [];
    final warmupTag = await ref.read(tagRepoProvider).findByName('开嗓');
    if (warmupTag == null) return [];
    final candidates = await ref
        .read(songRepoProvider)
        .fetchSongsByTagSorted(warmupTag.id);
    if (candidates.isEmpty) return [];
    final rng = Random();
    final pool = avoidRepeat
        ? candidates.where((s) => !usedIds.contains(s.id)).toList()
        : List<Song>.from(candidates);
    if (pool.isEmpty) return [];
    pool.shuffle(rng);
    final take = avoidRepeat
        ? min<int>(state.warmupCount, pool.length)
        : state.warmupCount;
    return List.generate(take, (index) {
      if (avoidRepeat) {
        return pool[index];
      }
      return pool[rng.nextInt(pool.length)];
    });
  }

  List<Song> _pickSongs(
    List<Song> candidates,
    int desiredCount, {
    required bool avoidRepeat,
    int? lastSongId,
  }) {
    if (candidates.isEmpty || desiredCount <= 0) return [];
    if (!avoidRepeat) {
      return _pickSongsWithSpacing(
        candidates,
        desiredCount,
        lastSongId: lastSongId,
      );
    }
    final rng = Random();
    final pool = List<Song>.from(candidates);
    pool.shuffle(rng);
    final takeCount = min(desiredCount, pool.length);
    return pool.take(takeCount).toList();
  }

  List<Song> _pickSongsWithSpacing(
    List<Song> candidates,
    int desiredCount, {
    int? lastSongId,
  }) {
    final rng = Random();
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

  Future<List<Song>> _loadSourceSongs() {
    final songRepo = ref.read(songRepoProvider);
    switch (state.sourceType) {
      case BrushSourceType.all:
        return songRepo.fetchAllSortedByNorm();
      case BrushSourceType.tag:
        if (state.selectedTagId == null) return Future.value([]);
        return songRepo.fetchSongsByTagSorted(state.selectedTagId!);
      case BrushSourceType.playlist:
        if (state.selectedPlaylistId == null) return Future.value([]);
        return ref
            .read(playlistRepoProvider)
            .songsInPlaylistSortedByNorm(state.selectedPlaylistId!);
    }
  }

  Future<List<Song>> loadCandidates() {
    return _loadSourceSongs();
  }
}
