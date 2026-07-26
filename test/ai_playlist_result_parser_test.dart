import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sing_list/ai/ai_exception.dart';
import 'package:sing_list/ai_playlist/ai_playlist_models.dart';
import 'package:sing_list/ai_playlist/ai_playlist_result_parser.dart';

void main() {
  const parser = AiPlaylistResultParser();
  const song1 = AiPlaylistCatalogSong(
    id: 1,
    title: '一',
    artist: '歌手',
    tags: ['抒情'],
    playlists: [],
    hasLyrics: false,
  );
  const song2 = AiPlaylistCatalogSong(
    id: 2,
    title: '二',
    artist: '歌手',
    tags: [],
    playlists: [],
    hasLyrics: false,
  );
  const candidates = {1: song1, 2: song2};

  String response({
    Object? recommendations = const [],
    Object? external = const [],
    bool needsClarification = false,
    Object? question,
  }) =>
      jsonEncode({
        'reply': needsClarification ? '需要确认' : '推荐如下',
        'needsClarification': needsClarification,
        'clarifyingQuestion': question,
        'playlistTitle': needsClarification ? null : '今晚唱',
        'recommendations': recommendations,
        'externalRecommendations': external,
      });

  test('parses valid JSON and Markdown JSON fences', () {
    final content = response(
      recommendations: [
        {'songId': 1, 'reason': '适合开场'},
        {'songId': 2, 'reason': '自然衔接'},
      ],
    );
    final result = parser.parse(
      '```json\n$content\n```',
      candidateSongs: candidates,
      allowExternal: false,
    );

    expect(result.recommendations.map((item) => item.song.id), [1, 2]);
    expect(result.playlistTitle, '今晚唱');
  });

  test('filters invalid ids and deduplicates while keeping valid order', () {
    final result = parser.parse(
      response(
        recommendations: [
          {'songId': 999, 'reason': '不存在'},
          {'songId': 2, 'reason': '先唱'},
          {'songId': 2, 'reason': '重复'},
          {'songId': 1, 'reason': '后唱'},
        ],
      ),
      candidateSongs: candidates,
      allowExternal: false,
    );

    expect(result.recommendations.map((item) => item.song.id), [2, 1]);
    expect(result.filteredRecommendationCount, 2);
  });

  test('reports when every local recommendation is filtered', () {
    final result = parser.parse(
      response(
        recommendations: [
          {'songId': 999, 'reason': '不存在'},
          {'songId': '1', 'reason': 'ID 类型错误'},
        ],
      ),
      candidateSongs: candidates,
      allowExternal: false,
    );

    expect(result.recommendations, isEmpty);
    expect(result.filteredRecommendationCount, 2);
  });

  test('filters external results when disabled and rejects forged ids', () {
    final external = [
      {'title': '外部歌', 'artist': '歌手', 'reason': '发现新歌'},
    ];
    final disabled = parser.parse(
      response(external: external),
      candidateSongs: candidates,
      allowExternal: false,
    );
    expect(disabled.externalRecommendations, isEmpty);

    final enabled = parser.parse(
      response(
        external: [
          {
            'songId': 1,
            'title': '伪装歌曲',
            'artist': '歌手',
            'reason': '不允许',
          },
          ...external,
        ],
      ),
      candidateSongs: candidates,
      allowExternal: true,
    );
    expect(enabled.externalRecommendations.single.title, '外部歌');
    expect(enabled.filteredExternalCount, 1);
  });

  test('represents a clarification response', () {
    final result = parser.parse(
      response(
        needsClarification: true,
        question: '更想唱日语还是中文？',
      ),
      candidateSongs: candidates,
      allowExternal: false,
    );

    expect(result.needsClarification, isTrue);
    expect(result.clarifyingQuestion, '更想唱日语还是中文？');
    expect(result.recommendations, isEmpty);
  });

  test('reports invalid JSON clearly', () {
    expect(
      () => parser.parse(
        'not-json',
        candidateSongs: candidates,
        allowExternal: false,
      ),
      throwsA(
        isA<AiException>().having(
          (error) => error.message,
          'message',
          contains('非法 JSON'),
        ),
      ),
    );
  });
}
