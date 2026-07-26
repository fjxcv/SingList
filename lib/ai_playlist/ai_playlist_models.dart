import 'dart:convert';

class AiPlaylistCatalogSong {
  const AiPlaylistCatalogSong({
    required this.id,
    required this.title,
    required this.artist,
    required this.tags,
    required this.playlists,
    required this.hasLyrics,
  });

  final int id;
  final String title;
  final String artist;
  final List<String> tags;
  final List<String> playlists;
  final bool hasLyrics;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'tags': tags,
        'playlists': playlists,
        'hasLyrics': hasLyrics,
      };
}

class SongCatalogContext {
  const SongCatalogContext({
    required this.songs,
    required this.totalSongCount,
    required this.isComplete,
    this.scopeNotice,
  });

  final List<AiPlaylistCatalogSong> songs;
  final int totalSongCount;
  final bool isComplete;
  final String? scopeNotice;

  Map<int, AiPlaylistCatalogSong> get songsById => {
        for (final song in songs) song.id: song,
      };

  String toPromptJson({required bool allowExternal}) => jsonEncode({
        'allowExternal': allowExternal,
        'catalogScope': {
          'totalSongs': totalSongCount,
          'candidateSongs': songs.length,
          'complete': isComplete,
          if (scopeNotice != null) 'notice': scopeNotice,
        },
        'songs': songs.map((song) => song.toJson()).toList(),
      });
}

class AiPlaylistHistoryMessage {
  const AiPlaylistHistoryMessage({
    required this.role,
    required this.content,
  });

  final String role;
  final String content;
}

class AiPlaylistRecommendation {
  const AiPlaylistRecommendation({
    required this.song,
    required this.reason,
  });

  final AiPlaylistCatalogSong song;
  final String reason;
}

class AiExternalRecommendation {
  const AiExternalRecommendation({
    required this.title,
    required this.artist,
    required this.reason,
  });

  final String title;
  final String artist;
  final String reason;
}

class AiPlaylistResult {
  const AiPlaylistResult({
    required this.reply,
    required this.needsClarification,
    required this.clarifyingQuestion,
    required this.playlistTitle,
    required this.recommendations,
    required this.externalRecommendations,
    required this.filteredRecommendationCount,
    required this.filteredExternalCount,
  });

  final String reply;
  final bool needsClarification;
  final String? clarifyingQuestion;
  final String? playlistTitle;
  final List<AiPlaylistRecommendation> recommendations;
  final List<AiExternalRecommendation> externalRecommendations;
  final int filteredRecommendationCount;
  final int filteredExternalCount;

  String toHistoryContent() => jsonEncode({
        'reply': reply,
        'needsClarification': needsClarification,
        'clarifyingQuestion': clarifyingQuestion,
        'playlistTitle': playlistTitle,
        'recommendations': [
          for (final item in recommendations)
            {
              'songId': item.song.id,
              'reason': item.reason,
            },
        ],
        'externalRecommendations': [
          for (final item in externalRecommendations)
            {
              'title': item.title,
              'artist': item.artist,
              'reason': item.reason,
            },
        ],
      });
}

class AiPlaylistServiceResult {
  const AiPlaylistServiceResult({
    required this.result,
    required this.catalog,
    required this.actualModel,
  });

  final AiPlaylistResult result;
  final SongCatalogContext catalog;
  final String actualModel;
}

class AiPlaylistSaveResult {
  const AiPlaylistSaveResult({
    required this.playlistId,
    required this.savedSongIds,
    required this.filteredMissingCount,
  });

  final int playlistId;
  final List<int> savedSongIds;
  final int filteredMissingCount;
}
