import 'dart:convert';

import '../ai/ai_exception.dart';
import 'ai_playlist_models.dart';

class AiPlaylistResultParser {
  const AiPlaylistResultParser();

  AiPlaylistResult parse(
    String content, {
    required Map<int, AiPlaylistCatalogSong> candidateSongs,
    required bool allowExternal,
  }) {
    final jsonText = _stripMarkdownFence(content);
    late final dynamic decoded;
    try {
      decoded = jsonDecode(jsonText);
    } on FormatException {
      throw const AiException(
        AiErrorKind.invalidResponse,
        'AI 返回了非法 JSON，请重试',
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const AiException(
        AiErrorKind.invalidResponse,
        'AI 返回的推荐结果不是 JSON 对象',
      );
    }

    final reply = decoded['reply'];
    final needsClarification = decoded['needsClarification'];
    final clarifyingQuestion = decoded['clarifyingQuestion'];
    final playlistTitle = decoded['playlistTitle'];
    final rawRecommendations = decoded['recommendations'];
    final rawExternal = decoded['externalRecommendations'];
    if (reply is! String ||
        needsClarification is! bool ||
        clarifyingQuestion is! String? ||
        playlistTitle is! String? ||
        rawRecommendations is! List ||
        rawExternal is! List) {
      throw const AiException(
        AiErrorKind.invalidResponse,
        'AI 返回的推荐字段缺失或类型不正确',
      );
    }
    if (reply.trim().isEmpty) {
      throw const AiException(
        AiErrorKind.invalidResponse,
        'AI 返回的 reply 不能为空',
      );
    }
    if (needsClarification &&
        (clarifyingQuestion == null || clarifyingQuestion.trim().isEmpty)) {
      throw const AiException(
        AiErrorKind.invalidResponse,
        'AI 表示需要追问，但没有返回 clarifyingQuestion',
      );
    }

    final recommendations = <AiPlaylistRecommendation>[];
    final seenSongIds = <int>{};
    var filteredRecommendationCount = 0;
    for (final value in rawRecommendations) {
      if (value is! Map) {
        filteredRecommendationCount++;
        continue;
      }
      final songId = value['songId'];
      final reason = value['reason'];
      final song = songId is int ? candidateSongs[songId] : null;
      if (song == null || reason is! String || reason.trim().isEmpty) {
        filteredRecommendationCount++;
        continue;
      }
      if (!seenSongIds.add(songId as int)) {
        filteredRecommendationCount++;
        continue;
      }
      recommendations.add(
        AiPlaylistRecommendation(song: song, reason: reason.trim()),
      );
    }

    final externalRecommendations = <AiExternalRecommendation>[];
    var filteredExternalCount = 0;
    final seenExternal = <String>{};
    for (final value in rawExternal) {
      if (!allowExternal) {
        filteredExternalCount++;
        continue;
      }
      if (value is! Map || value.containsKey('songId')) {
        filteredExternalCount++;
        continue;
      }
      final title = value['title'];
      final artist = value['artist'];
      final reason = value['reason'];
      if (title is! String ||
          artist is! String ||
          reason is! String ||
          title.trim().isEmpty ||
          artist.trim().isEmpty ||
          reason.trim().isEmpty) {
        filteredExternalCount++;
        continue;
      }
      final key = '${title.trim().toLowerCase()}\u0000'
          '${artist.trim().toLowerCase()}';
      if (!seenExternal.add(key)) {
        filteredExternalCount++;
        continue;
      }
      externalRecommendations.add(
        AiExternalRecommendation(
          title: title.trim(),
          artist: artist.trim(),
          reason: reason.trim(),
        ),
      );
    }

    return AiPlaylistResult(
      reply: reply.trim(),
      needsClarification: needsClarification,
      clarifyingQuestion: clarifyingQuestion?.trim(),
      playlistTitle: playlistTitle?.trim(),
      recommendations: recommendations,
      externalRecommendations: externalRecommendations,
      filteredRecommendationCount: filteredRecommendationCount,
      filteredExternalCount: filteredExternalCount,
    );
  }

  String _stripMarkdownFence(String value) {
    final trimmed = value.trim();
    final match = RegExp(
      r'^```(?:json)?\s*([\s\S]*?)\s*```$',
      caseSensitive: false,
    ).firstMatch(trimmed);
    return match?.group(1)?.trim() ?? trimmed;
  }
}
