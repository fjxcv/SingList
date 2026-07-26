import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sing_list/lyrics/lyric_search_service.dart';

void main() {
  test('encodes track and artist query parameters', () {
    final uri = LyricSearchService().buildSearchUri(
      trackName: '空 白&歌',
      artistName: '歌手/组合',
    );

    expect(uri.queryParameters['track_name'], '空 白&歌');
    expect(uri.queryParameters['artist_name'], '歌手/组合');
  });

  test('parses results and prefers plain lyrics', () {
    final values = [
      {
        'id': 1,
        'trackName': 'Song',
        'artistName': 'Artist',
        'albumName': 'Album',
        'duration': 123.4,
        'instrumental': false,
        'plainLyrics': 'plain\nlyrics',
        'syncedLyrics': '[00:01.00]synced',
      },
    ];

    final result = LyricSearchService().parseCandidates(values);

    expect(result.single.lyrics, 'plain\nlyrics');
    expect(result.single.albumName, 'Album');
    expect(result.single.durationSeconds, 123.4);
  });

  test('uses synced lyrics after removing timestamps', () {
    final result = LyricSearchService().parseCandidates([
      {
        'id': 1,
        'trackName': 'Song',
        'artistName': 'Artist',
        'instrumental': false,
        'plainLyrics': null,
        'syncedLyrics': '[00:01.00]line one\r\n[01:02.33]line two',
      },
    ]);

    expect(result.single.lyrics, 'line one\nline two');
  });

  test('filters empty lyrics and keeps instrumental marker', () {
    final result = LyricSearchService().parseCandidates([
      {
        'id': 1,
        'trackName': 'Empty',
        'artistName': 'Artist',
        'instrumental': false,
        'plainLyrics': '',
        'syncedLyrics': null,
      },
      {
        'id': 2,
        'trackName': 'Instrumental',
        'artistName': 'Artist',
        'instrumental': true,
        'plainLyrics': null,
        'syncedLyrics': null,
      },
    ]);

    expect(result, hasLength(1));
    expect(result.single.instrumental, isTrue);
  });

  test('deduplicates equivalent lyrics and keeps different versions', () {
    Map<String, dynamic> item(int id, String lyrics) => {
          'id': id,
          'trackName': 'Song',
          'artistName': 'Artist',
          'instrumental': false,
          'plainLyrics': lyrics,
        };

    final result = LyricSearchService().parseCandidates([
      item(1, 'same  line \r\n chorus'),
      item(2, 'same line\nchorus'),
      item(3, 'different version'),
    ]);

    expect(result.map((item) => item.id), [1, 3]);
  });

  test('reports network errors and invalid responses', () async {
    final networkService = LyricSearchService(
      httpClient: MockClient((_) => throw http.ClientException('offline')),
    );
    await expectLater(
      networkService.search(trackName: 'Song', artistName: 'Artist'),
      throwsA(isA<LyricSearchException>()),
    );

    final invalidService = LyricSearchService(
      httpClient: MockClient(
        (_) async => http.Response(jsonEncode({'not': 'a list'}), 200),
      ),
    );
    await expectLater(
      invalidService.search(trackName: 'Song', artistName: 'Artist'),
      throwsA(isA<LyricSearchException>()),
    );
  });
}
