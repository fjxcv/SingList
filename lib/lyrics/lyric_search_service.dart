import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'lyric_candidate.dart';

class LyricSearchException implements Exception {
  const LyricSearchException(this.message);
  final String message;

  @override
  String toString() => message;
}

class LyricSearchService {
  LyricSearchService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;
  static const _baseUrl = 'https://lrclib.net/api/search';

  Uri buildSearchUri({required String trackName, required String artistName}) {
    return Uri.parse(_baseUrl).replace(
      queryParameters: {
        'track_name': trackName.trim(),
        if (artistName.trim().isNotEmpty) 'artist_name': artistName.trim(),
      },
    );
  }

  Future<List<LyricCandidate>> search({
    required String trackName,
    required String artistName,
  }) async {
    if (trackName.trim().isEmpty) {
      throw const LyricSearchException('请填写歌名');
    }
    try {
      final response = await _httpClient.get(
        buildSearchUri(trackName: trackName, artistName: artistName),
        headers: const {
          'User-Agent': 'SingList/0.1.4 (https://github.com/fjxcv/SingList)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw LyricSearchException(
          'LRCLIB 搜索失败（HTTP ${response.statusCode}）',
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! List) {
        throw const LyricSearchException('LRCLIB 返回格式不正确');
      }
      return parseCandidates(decoded);
    } on LyricSearchException {
      rethrow;
    } on FormatException {
      throw const LyricSearchException('LRCLIB 返回了无法解析的数据');
    } on TimeoutException {
      throw const LyricSearchException('连接 LRCLIB 超时，请检查网络或代理后重试');
    } on SocketException {
      throw const LyricSearchException('无法连接 LRCLIB，请检查网络、DNS 或代理');
    } on http.ClientException {
      throw const LyricSearchException('无法连接 LRCLIB，请检查网络后重试');
    }
  }

  Future<void> checkAvailability({
    Duration timeout = const Duration(seconds: 6),
  }) async {
    try {
      final response = await _httpClient.get(
        Uri.parse(_baseUrl).replace(
          queryParameters: const {'track_name': 'SingList connectivity check'},
        ),
        headers: const {
          'User-Agent': 'SingList/0.1.6 (https://github.com/fjxcv/SingList)',
          'Accept': 'application/json',
        },
      ).timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw LyricSearchException(
          '歌词服务暂时不可用（HTTP ${response.statusCode}）',
        );
      }
      if (jsonDecode(response.body) is! List) {
        throw const LyricSearchException('歌词服务返回格式不正确');
      }
    } on LyricSearchException {
      rethrow;
    } on TimeoutException {
      throw const LyricSearchException('歌词服务连接检查超时，请稍后重试');
    } on SocketException {
      throw const LyricSearchException('无法连接歌词服务，请检查网络、DNS 或代理');
    } on http.ClientException {
      throw const LyricSearchException('歌词服务网络请求失败，请稍后重试');
    } on FormatException {
      throw const LyricSearchException('歌词服务返回了无法解析的数据');
    }
  }

  List<LyricCandidate> parseCandidates(List<dynamic> values) {
    final result = <LyricCandidate>[];
    final seen = <String>{};
    for (final value in values) {
      if (value is! Map) continue;
      final map = Map<String, dynamic>.from(value);
      final instrumental = map['instrumental'] == true;
      final plain = map['plainLyrics'];
      final synced = map['syncedLyrics'];
      final lyrics = normalizeLyrics(
        plain is String && plain.trim().isNotEmpty
            ? plain
            : synced is String
                ? stripLrcTimestamps(synced)
                : '',
      );
      if (!instrumental && lyrics.trim().isEmpty) continue;
      final fingerprint = canonicalFingerprint(lyrics);
      if (!instrumental && !seen.add(fingerprint)) continue;
      final id = map['id'];
      final trackName = map['trackName'];
      final artistName = map['artistName'];
      if (id is! int || trackName is! String || artistName is! String) continue;
      final duration = map['duration'];
      result.add(
        LyricCandidate(
          id: id,
          trackName: trackName,
          artistName: artistName,
          albumName:
              map['albumName'] is String ? map['albumName'] as String : null,
          durationSeconds: duration is num ? duration.toDouble() : null,
          instrumental: instrumental,
          lyrics: lyrics,
        ),
      );
    }
    return result;
  }

  static String stripLrcTimestamps(String value) {
    return value
        .split(RegExp(r'\r\n?|\n'))
        .map(
          (line) => line.replaceFirst(
            RegExp(r'^(?:\[[0-9]{1,3}:[0-9]{2}(?:[.:][0-9]{1,3})?\])+\s*'),
            '',
          ),
        )
        .join('\n');
  }

  static String normalizeLyrics(String value) {
    return value
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .map((line) => line.trimRight())
        .join('\n');
  }

  static String canonicalFingerprint(String value) {
    return stripLrcTimestamps(normalizeLyrics(value))
        .split('\n')
        .map((line) => line.trim().replaceAll(RegExp(r'\s+'), ' '))
        .join('\n');
  }
}
