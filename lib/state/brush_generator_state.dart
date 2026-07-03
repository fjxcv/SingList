import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/app_database.dart';
import '../repository/playlist_repository.dart';
import '../repository/song_repository.dart';
import '../repository/tag_repository.dart';
import 'providers.dart';

enum BrushSourceType { all, tag, playlist }

enum BrushPhase { warmup, main }

enum BrushAction { favorite, like, skip }

class BrushDecision {
  const BrushDecision({
    required this.phase,
    required this.song,
    required this.action,
  });

  final BrushPhase phase;
  final Song song;
  final BrushAction action;
}

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
    this.phase = BrushPhase.main,
    this.warmupFavorites = const [],
    this.warmupLikes = const [],
    this.history = const [],
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
  final BrushPhase phase;
  final List<Song> warmupFavorites;
  final List<Song> warmupLikes;
  final List<BrushDecision> history;

  Song? get currentSong =>
      currentIndex < songs.length ? songs[currentIndex] : null;

  bool get completed =>
      phase == BrushPhase.main &&
      ((songs.isNotEmpty && currentIndex >= songs.length) ||
          (songs.isEmpty && inBrushMode && !isLoading));

  bool get canGoPrevious => currentIndex > 0;

  String get phaseLabel =>
      phase == BrushPhase.warmup ? '开嗓暖场' : '刷歌';

  double get progressValue =>
      songs.isEmpty ? 0 : currentIndex / songs.length;

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
    BrushPhase? phase,
    List<Song>? warmupFavorites,
    List<Song>? warmupLikes,
    List<BrushDecision>? history,
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
      phase: phase ?? this.phase,
      warmupFavorites: warmupFavorites ?? this.warmupFavorites,
      warmupLikes: warmupLikes ?? this.warmupLikes,
      history: history ?? this.history,
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
      final warmupSongs = await _loadWarmupSongs();
      final warmupSongIds = warmupSongs.map((s) => s.id).toSet();
      final shouldStartWarmup =
          state.warmupEnabled && state.warmupCount > 0 && warmupSongs.isNotEmpty;

      if (shouldStartWarmup) {
        final shuffled = List<Song>.from(warmupSongs)..shuffle(Random());
        state = state.copyWith(
          songs: shuffled,
          currentIndex: 0,
          favorites: const [],
          likes: const [],
          isLoading: false,
          error: null,
          warmupSongs: warmupSongs,
          warmupSongIds: warmupSongIds,
          warmupSkippedIds: const {},
          warmupFavorites: const [],
          warmupLikes: const [],
          history: const [],
          phase: BrushPhase.warmup,
        );
        return;
      }

      final mainSongs = await _loadMainSongs(warmupSongIds);
      if (mainSongs.isEmpty) {
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
      state = state.copyWith(
        songs: mainSongs,
        currentIndex: 0,
        favorites: const [],
        likes: const [],
        isLoading: false,
        error: null,
        warmupSongs: warmupSongs,
        warmupSongIds: warmupSongIds,
        warmupSkippedIds: const {},
        warmupFavorites: const [],
        warmupLikes: const [],
        history: const [],
        phase: BrushPhase.main,
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
    _recordDecision(BrushAction.favorite);
    if (state.phase == BrushPhase.warmup) {
      final warmupSkippedIds = Set<int>.from(state.warmupSkippedIds)
        ..remove(song.id);
      state = state.copyWith(
        warmupFavorites: [...state.warmupFavorites, song],
        warmupSkippedIds: warmupSkippedIds,
        currentIndex: state.currentIndex + 1,
      );
      _checkPhaseTransition();
      return;
    }
    state = state.copyWith(
      favorites: [...state.favorites, song],
      currentIndex: state.currentIndex + 1,
    );
  }

  void markLike() {
    final song = state.currentSong;
    if (song == null) return;
    _recordDecision(BrushAction.like);
    if (state.phase == BrushPhase.warmup) {
      final warmupSkippedIds = Set<int>.from(state.warmupSkippedIds)
        ..remove(song.id);
      state = state.copyWith(
        warmupLikes: [...state.warmupLikes, song],
        warmupSkippedIds: warmupSkippedIds,
        currentIndex: state.currentIndex + 1,
      );
      _checkPhaseTransition();
      return;
    }
    state = state.copyWith(
      likes: [...state.likes, song],
      currentIndex: state.currentIndex + 1,
    );
  }

  void skip() {
    final song = state.currentSong;
    if (song == null) return;
    _recordDecision(BrushAction.skip);
    if (state.phase == BrushPhase.warmup) {
      final warmupSkippedIds = Set<int>.from(state.warmupSkippedIds)
        ..add(song.id);
      state = state.copyWith(
        warmupSkippedIds: warmupSkippedIds,
        currentIndex: state.currentIndex + 1,
      );
      _checkPhaseTransition();
      return;
    }
    state = state.copyWith(currentIndex: state.currentIndex + 1);
  }

  void goPrevious() {
    if (!state.canGoPrevious || state.history.isEmpty) return;
    final decision = state.history.last;
    final newHistory = state.history.sublist(0, state.history.length - 1);
    state = state.copyWith(
      currentIndex: state.currentIndex - 1,
      history: newHistory,
    );
    _undoDecision(decision);
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
      warmupFavorites: const [],
      warmupLikes: const [],
      history: const [],
      phase: BrushPhase.main,
    );
  }

  void _recordDecision(BrushAction action) {
    final song = state.currentSong;
    if (song == null) return;
    state = state.copyWith(
      history: [
        ...state.history,
        BrushDecision(phase: state.phase, song: song, action: action),
      ],
    );
  }

  void _undoDecision(BrushDecision decision) {
    switch (decision.phase) {
      case BrushPhase.warmup:
        switch (decision.action) {
          case BrushAction.favorite:
            state = state.copyWith(
              warmupFavorites: state.warmupFavorites
                  .where((s) => s.id != decision.song.id)
                  .toList(),
            );
          case BrushAction.like:
            state = state.copyWith(
              warmupLikes: state.warmupLikes
                  .where((s) => s.id != decision.song.id)
                  .toList(),
            );
          case BrushAction.skip:
            final warmupSkippedIds = Set<int>.from(state.warmupSkippedIds)
              ..remove(decision.song.id);
            state = state.copyWith(warmupSkippedIds: warmupSkippedIds);
        }
      case BrushPhase.main:
        switch (decision.action) {
          case BrushAction.favorite:
            state = state.copyWith(
              favorites: state.favorites
                  .where((s) => s.id != decision.song.id)
                  .toList(),
            );
          case BrushAction.like:
            state = state.copyWith(
              likes: state.likes
                  .where((s) => s.id != decision.song.id)
                  .toList(),
            );
          case BrushAction.skip:
            break;
        }
    }
  }

  Future<void> _checkPhaseTransition() async {
    if (state.phase != BrushPhase.warmup) return;
    if (state.currentIndex < state.songs.length) return;
    state = state.copyWith(isLoading: true);
    await _enterMainPhase();
  }

  Future<void> _enterMainPhase() async {
    try {
      final mainSongs = await _loadMainSongs(state.warmupSongIds);
      if (mainSongs.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          songs: const [],
          phase: BrushPhase.main,
        );
        return;
      }
      state = state.copyWith(
        songs: mainSongs,
        currentIndex: 0,
        isLoading: false,
        phase: BrushPhase.main,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '$e');
    }
  }

  Future<List<Song>> _loadMainSongs(Set<int> excludeIds) async {
    final sourceSongs = await _loadSourceSongs();
    return sourceSongs.where((s) => !excludeIds.contains(s.id)).toList();
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
    final forced = List<Song>.from(state.warmupFavorites);
    final liked = state.warmupLikes
        .where((s) => !state.warmupSkippedIds.contains(s.id))
        .where((s) => !forced.any((f) => f.id == s.id))
        .toList();
    final remaining = state.warmupCount - forced.length;
    final selected = <Song>[...forced];
    if (remaining > 0 && liked.isNotEmpty) {
      final pool = List<Song>.from(liked)..shuffle(Random());
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
    final forced = List<Song>.from(state.warmupFavorites);
    final liked = state.warmupLikes
        .where((s) => !state.warmupSkippedIds.contains(s.id))
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
