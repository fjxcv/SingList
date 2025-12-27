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

  Future<Playlist?> generateQueue() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final candidates = await _loadSourceSongs();
      if (candidates.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          error: '请先选择有效来源',
        );
        return null;
      }

      final usedIds = <int>{};
      final warmups = await _pickWarmups(usedIds);
      if (state.avoidRepeat) {
        usedIds.addAll(warmups.map((e) => e.id));
      }

      final mainSongs = _pickSongs(
        candidates.where((s) => !usedIds.contains(s.id)).toList(),
        state.count,
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

  Future<List<Song>> _pickWarmups(Set<int> usedIds) async {
    if (!state.warmupEnabled || state.warmupCount <= 0) return [];
    final warmupTag = await ref.read(tagRepoProvider).findByName('开嗓');
    if (warmupTag == null) return [];
    final candidates = await ref
        .read(songRepoProvider)
        .fetchSongsByTagSorted(warmupTag.id);
    if (candidates.isEmpty) return [];
    final rng = Random();
    final pool = state.avoidRepeat
        ? candidates.where((s) => !usedIds.contains(s.id)).toList()
        : List<Song>.from(candidates);
    if (pool.isEmpty) return [];
    pool.shuffle(rng);
    final take = state.avoidRepeat
        ? min<int>(state.warmupCount, pool.length)
        : state.warmupCount;
    return List.generate(take, (index) {
      if (state.avoidRepeat) {
        return pool[index];
      }
      return pool[rng.nextInt(pool.length)];
    });
  }

  List<Song> _pickSongs(List<Song> candidates, int desiredCount) {
    if (candidates.isEmpty || desiredCount <= 0) return [];
    final rng = Random();
    if (!state.avoidRepeat) {
      return List.generate(
        desiredCount,
        (_) => candidates[rng.nextInt(candidates.length)],
      );
    }
    final pool = List<Song>.from(candidates);
    pool.shuffle(rng);
    final takeCount = min(desiredCount, pool.length);
    return pool.take(takeCount).toList();
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
}
