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
    this.inBrushMode = false,
    this.warmupSongIds = const {},
    this.warmupSkippedIds = const {},
    this.warmupSongs = const [],
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
  final bool inBrushMode;
  final Set<int> warmupSongIds;
  final Set<int> warmupSkippedIds;
  final List<Song> warmupSongs;

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
    bool? inBrushMode,
    Set<int>? warmupSongIds,
    Set<int>? warmupSkippedIds,
    List<Song>? warmupSongs,
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
      inBrushMode: inBrushMode ?? this.inBrushMode,
      warmupSongIds: warmupSongIds ?? this.warmupSongIds,
      warmupSkippedIds: warmupSkippedIds ?? this.warmupSkippedIds,
      warmupSongs: warmupSongs ?? this.warmupSongs,
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
      inBrushMode: false,
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
    final clamped = value < 0
        ? 0
        : value > 20
            ? 20
            : value;
    state = state.copyWith(warmupCount: clamped);
  }

  Future<void> loadSongs() async {
    state = state.copyWith(
      isLoading: true,
      error: null,
      inBrushMode: true,
    );
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
          inBrushMode: false,
        );
        return;
      }
      final warmupSongs = await _loadWarmupSongs();
      final warmupSongIds = warmupSongs.map((s) => s.id).toSet();
      state = state.copyWith(
        songs: songs,
        currentIndex: 0,
        favorites: const [],
        likes: const [],
        isLoading: false,
        error: null,
        warmupSongs: warmupSongs,
        warmupSongIds: warmupSongIds,
        warmupSkippedIds: const {},
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '$e');
    }
  }

  Future<int> fetchWarmupTagCount() async {
    final warmupSongs = await _loadWarmupSongs();
    return warmupSongs.length;
  }

  void markFavorite() {
    final song = state.currentSong;
    if (song == null) return;
    final warmupSkippedIds = Set<int>.from(state.warmupSkippedIds);
    if (state.warmupSongIds.contains(song.id)) {
      warmupSkippedIds.remove(song.id);
    }
    final updatedFavorites = [...state.favorites, song];
    state = state.copyWith(
      favorites: updatedFavorites,
      currentIndex: state.currentIndex + 1,
      warmupSkippedIds: warmupSkippedIds,
    );
  }

  void markLike() {
    final song = state.currentSong;
    if (song == null) return;
    final warmupSkippedIds = Set<int>.from(state.warmupSkippedIds);
    if (state.warmupSongIds.contains(song.id)) {
      warmupSkippedIds.remove(song.id);
    }
    final updatedLikes = [...state.likes, song];
    state = state.copyWith(
      likes: updatedLikes,
      currentIndex: state.currentIndex + 1,
      warmupSkippedIds: warmupSkippedIds,
    );
  }

  void skip() {
    if (state.currentSong == null) return;
    final warmupSkippedIds = Set<int>.from(state.warmupSkippedIds);
    final song = state.currentSong!;
    if (state.warmupSongIds.contains(song.id)) {
      warmupSkippedIds.add(song.id);
    }
    state = state.copyWith(currentIndex: state.currentIndex + 1);
    if (warmupSkippedIds.length != state.warmupSkippedIds.length) {
      state = state.copyWith(warmupSkippedIds: warmupSkippedIds);
    }
  }

  Future<Playlist?> createQueue({List<Song> selectedWarmups = const []}) async {
    final playlistRepo = ref.read(playlistRepoProvider);
    final songs = await _mergeOrderWithWarmup(selectedWarmups: selectedWarmups);
    if (songs.isEmpty) return null;
    return playlistRepo.createQueueWithSongs(
      songs.map((s) => s.id).toList(),
    );
  }

  void exitBrushMode() {
    state = state.copyWith(
      inBrushMode: false,
      songs: const [],
      currentIndex: 0,
      favorites: const [],
      likes: const [],
      isLoading: false,
      error: null,
      warmupSongIds: const {},
      warmupSkippedIds: const {},
      warmupSongs: const [],
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

  Future<List<Song>> _mergeOrderWithWarmup({List<Song> selectedWarmups = const []}) async {
    final ordered = <Song>[];
    if (state.warmupEnabled && state.warmupCount > 0) {
      if (selectedWarmups.isNotEmpty) {
        ordered.addAll(selectedWarmups.take(state.warmupCount));
      } else {
        ordered.addAll(await _pickWarmups());
      }
    }
    final warmupIds = ordered.map((e) => e.id).toSet();
    ordered.addAll(state.favorites.where((s) => !warmupIds.contains(s.id)));
    ordered.addAll(state.likes.where((s) => !warmupIds.contains(s.id)));
    return ordered;
  }

  Future<List<Song>> _pickWarmups() async {
    if (!state.warmupEnabled || state.warmupCount <= 0) return [];
    final forced = state.favorites.where((s) => state.warmupSongIds.contains(s.id)).toList();
    final liked = state.likes
        .where((s) => state.warmupSongIds.contains(s.id) && !state.warmupSkippedIds.contains(s.id))
        .toList();
    final remaining = state.warmupCount - forced.length;
    final selected = <Song>[
      ...forced,
    ];
    if (remaining > 0 && liked.isNotEmpty) {
      final pool = List<Song>.from(liked);
      pool.shuffle(Random());
      selected.addAll(pool.take(min(remaining, pool.length)));
    }
    return selected;
  }

  Future<List<Song>> _loadWarmupSongs() async {
    final tagRepo = ref.read(tagRepoProvider);
    final warmupTag = await tagRepo.findByName('开嗓');
    if (warmupTag == null) return [];
    return ref.read(songRepoProvider).fetchSongsByTagSorted(warmupTag.id);
  }

  WarmupPlan buildWarmupPlan() {
    final forced = state.favorites.where((s) => state.warmupSongIds.contains(s.id)).toList();
    final liked = state.likes
        .where((s) => state.warmupSongIds.contains(s.id) && !state.warmupSkippedIds.contains(s.id))
        .where((s) => !forced.any((f) => f.id == s.id))
        .toList();
    final selectedIds = {
      ...forced.map((s) => s.id),
      ...liked.map((s) => s.id),
    };
    final extras = state.warmupSongs.where((s) => !selectedIds.contains(s.id)).toList();
    return WarmupPlan(
      requiredCount: state.warmupCount,
      forced: forced,
      liked: liked,
      extras: extras,
    );
  }

  List<Song> pickRandomLikedWarmups(List<Song> liked, int count) {
    if (count <= 0) return [];
    if (liked.length <= count) return liked;
    final pool = List<Song>.from(liked)..shuffle(Random());
    return pool.take(count).toList();
  }
}

class WarmupPlan {
  WarmupPlan({
    required this.requiredCount,
    required this.forced,
    required this.liked,
    required this.extras,
  });

  final int requiredCount;
  final List<Song> forced;
  final List<Song> liked;
  final List<Song> extras;
}
