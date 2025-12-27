import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/app_database.dart';
import '../repository/playlist_repository.dart';
import '../repository/song_repository.dart';
import '../repository/tag_repository.dart';
import 'providers.dart';

enum BrushSourceType { all, tag, playlist }

class BrushGeneratorState {
  const BrushGeneratorState({
    this.sourceType = BrushSourceType.all,
    this.selectedTagId,
    this.selectedPlaylistId,
    this.songs = const [],
    this.currentIndex = 0,
    this.favorites = const [],
    this.likes = const [],
    this.isLoading = false,
    this.error,
    this.warmupEnabled = true,
    this.warmupCount = 2,
  });

  final BrushSourceType sourceType;
  final int? selectedTagId;
  final int? selectedPlaylistId;
  final List<Song> songs;
  final int currentIndex;
  final List<Song> favorites;
  final List<Song> likes;
  final bool isLoading;
  final String? error;
  final bool warmupEnabled;
  final int warmupCount;

  Song? get currentSong =>
      currentIndex < songs.length ? songs[currentIndex] : null;

  bool get completed => songs.isNotEmpty && currentIndex >= songs.length;

  BrushGeneratorState copyWith({
    BrushSourceType? sourceType,
    int? selectedTagId,
    int? selectedPlaylistId,
    List<Song>? songs,
    int? currentIndex,
    List<Song>? favorites,
    List<Song>? likes,
    bool? isLoading,
    String? error,
    bool? warmupEnabled,
    int? warmupCount,
  }) {
    return BrushGeneratorState(
      sourceType: sourceType ?? this.sourceType,
      selectedTagId: selectedTagId ?? this.selectedTagId,
      selectedPlaylistId: selectedPlaylistId ?? this.selectedPlaylistId,
      songs: songs ?? this.songs,
      currentIndex: currentIndex ?? this.currentIndex,
      favorites: favorites ?? this.favorites,
      likes: likes ?? this.likes,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      warmupEnabled: warmupEnabled ?? this.warmupEnabled,
      warmupCount: warmupCount ?? this.warmupCount,
    );
  }
}

final brushGeneratorProvider =
    AutoDisposeNotifierProvider<BrushGeneratorNotifier, BrushGeneratorState>(
  BrushGeneratorNotifier.new,
);

class BrushGeneratorNotifier extends AutoDisposeNotifier<BrushGeneratorState> {
  @override
  BrushGeneratorState build() {
    return const BrushGeneratorState();
  }

  void updateSourceType(BrushSourceType type) {
    state = state.copyWith(
      sourceType: type,
      selectedTagId: type == BrushSourceType.tag ? state.selectedTagId : null,
      selectedPlaylistId:
          type == BrushSourceType.playlist ? state.selectedPlaylistId : null,
      songs: const [],
      favorites: const [],
      likes: const [],
      currentIndex: 0,
    );
  }

  void updateTag(int? tagId) {
    state = state.copyWith(selectedTagId: tagId);
  }

  void updatePlaylist(int? playlistId) {
    state = state.copyWith(selectedPlaylistId: playlistId);
  }

  void updateWarmupEnabled(bool value) {
    state = state.copyWith(warmupEnabled: value);
  }

  void updateWarmupCount(int value) {
    state = state.copyWith(warmupCount: value);
  }

  Future<void> loadSongs() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final songs = await _loadSourceSongs();
      if (songs.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          error: '请先选择有效来源',
          songs: const [],
          favorites: const [],
          likes: const [],
          currentIndex: 0,
        );
        return;
      }
      state = state.copyWith(
        songs: songs,
        currentIndex: 0,
        favorites: const [],
        likes: const [],
        isLoading: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '$e');
    }
  }

  void markFavorite() {
    final song = state.currentSong;
    if (song == null) return;
    final updatedFavorites = [...state.favorites, song];
    state = state.copyWith(
      favorites: updatedFavorites,
      currentIndex: state.currentIndex + 1,
    );
  }

  void markLike() {
    final song = state.currentSong;
    if (song == null) return;
    final updatedLikes = [...state.likes, song];
    state = state.copyWith(
      likes: updatedLikes,
      currentIndex: state.currentIndex + 1,
    );
  }

  void skip() {
    if (state.currentSong == null) return;
    state = state.copyWith(currentIndex: state.currentIndex + 1);
  }

  Future<Playlist?> createQueue() async {
    if (!state.completed) return null;
    final playlistRepo = ref.read(playlistRepoProvider);
    final songs = await _mergeOrderWithWarmup();
    return playlistRepo.createQueueWithSongs(
      songs.map((s) => s.id).toList(),
    );
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

  Future<List<Song>> _mergeOrderWithWarmup() async {
    final ordered = <Song>[];
    if (state.warmupEnabled && state.warmupCount > 0) {
      ordered.addAll(await _pickWarmups());
    }
    ordered.addAll(state.favorites);
    ordered.addAll(state.likes);
    return ordered;
  }

  Future<List<Song>> _pickWarmups() async {
    final tagRepo = ref.read(tagRepoProvider);
    final warmupTag = await tagRepo.findByName('开嗓');
    if (warmupTag == null) return [];
    final candidates = await ref
        .read(songRepoProvider)
        .fetchSongsByTagSorted(warmupTag.id);
    if (candidates.isEmpty) return [];
    final rng = Random();
    final pool = List<Song>.from(candidates);
    pool.shuffle(rng);
    return pool.take(state.warmupCount).toList();
  }
}
