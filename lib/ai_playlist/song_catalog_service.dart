import 'package:drift/drift.dart';

import '../data/db/app_database.dart';
import 'ai_playlist_models.dart';

class SongCatalogTooLargeException implements Exception {
  const SongCatalogTooLargeException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SongCatalogService {
  const SongCatalogService(
    this.db, {
    this.maxSongsPerRequest = 300,
    this.hardSongLimit = 1200,
  });

  final AppDatabase db;
  final int maxSongsPerRequest;
  final int hardSongLimit;

  Future<int> countSongs() async {
    final count = db.songs.id.count();
    final query = db.selectOnly(db.songs)..addColumns([count]);
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  Future<SongCatalogContext> buildContext({
    required String userQuery,
  }) async {
    final songs = await db.songDao.fetchAllSortedByNorm();
    if (songs.isEmpty) {
      return const SongCatalogContext(
        songs: [],
        totalSongCount: 0,
        isComplete: true,
      );
    }

    final tagsBySong = <int, List<String>>{};
    final tagRows = await db.customSelect(
      '''
      SELECT st.song_id AS song_id, t.name AS name
      FROM song_tags st
      INNER JOIN tags t ON t.id = st.tag_id
      ORDER BY t.name ASC
      ''',
      readsFrom: {db.songTags, db.tags},
    ).get();
    for (final row in tagRows) {
      (tagsBySong[row.read<int>('song_id')] ??= [])
          .add(row.read<String>('name'));
    }

    final playlistsBySong = <int, List<String>>{};
    final playlistRows = await db.customSelect(
      '''
      SELECT ps.song_id AS song_id, p.name AS name
      FROM playlist_songs ps
      INNER JOIN playlists p ON p.id = ps.playlist_id
      WHERE p.type = ?
      ORDER BY p.name ASC
      ''',
      variables: [Variable<int>(PlaylistType.normal.index)],
      readsFrom: {db.playlistSongs, db.playlists},
    ).get();
    for (final row in playlistRows) {
      (playlistsBySong[row.read<int>('song_id')] ??= [])
          .add(row.read<String>('name'));
    }

    final lyricRows = await db.customSelect(
      'SELECT song_id FROM song_lyrics',
      readsFrom: {db.songLyrics},
    ).get();
    final lyricSongIds =
        lyricRows.map((row) => row.read<int>('song_id')).toSet();

    final entries = [
      for (final song in songs)
        AiPlaylistCatalogSong(
          id: song.id,
          title: song.title,
          artist: song.artist,
          tags: List.unmodifiable(tagsBySong[song.id] ?? const []),
          playlists: List.unmodifiable(playlistsBySong[song.id] ?? const []),
          hasLyrics: lyricSongIds.contains(song.id),
        ),
    ];
    if (entries.length <= maxSongsPerRequest) {
      return SongCatalogContext(
        songs: entries,
        totalSongCount: entries.length,
        isComplete: true,
      );
    }

    final scored = [
      for (final song in entries) (song: song, score: _score(song, userQuery)),
    ]..sort((a, b) {
        final scoreOrder = b.score.compareTo(a.score);
        return scoreOrder != 0 ? scoreOrder : a.song.id.compareTo(b.song.id);
      });
    final matching = scored.where((entry) => entry.score > 0).toList();
    if (entries.length > hardSongLimit &&
        (matching.isEmpty || matching.length > maxSongsPerRequest * 2)) {
      throw const SongCatalogTooLargeException(
        '曲库较大，请在需求中补充歌手、语言、标签或歌单名称后再发送',
      );
    }

    final selected = <AiPlaylistCatalogSong>[];
    final selectedIds = <int>{};
    for (final entry in matching.take(maxSongsPerRequest * 4 ~/ 5)) {
      if (selectedIds.add(entry.song.id)) selected.add(entry.song);
    }

    final remainingSlots = maxSongsPerRequest - selected.length;
    if (remainingSlots > 0) {
      final unselected =
          entries.where((song) => !selectedIds.contains(song.id)).toList();
      final step = unselected.length / remainingSlots;
      for (var i = 0; i < remainingSlots && unselected.isNotEmpty; i++) {
        final index = (i * step).floor().clamp(0, unselected.length - 1);
        final song = unselected[index];
        if (selectedIds.add(song.id)) selected.add(song);
      }
    }

    return SongCatalogContext(
      songs: selected,
      totalSongCount: entries.length,
      isComplete: false,
      scopeNotice: '曲库共 ${entries.length} 首，本轮根据需求筛选并抽样发送 '
          '${selected.length} 首候选；回复不得声称参考了完整曲库。',
    );
  }

  int _score(AiPlaylistCatalogSong song, String userQuery) {
    final query = userQuery.trim().toLowerCase();
    if (query.isEmpty) return 0;
    var score = 0;
    void match(String value, int weight) {
      final normalized = value.trim().toLowerCase();
      if (normalized.isEmpty) return;
      if (query.contains(normalized)) score += weight;
    }

    match(song.title, 8);
    match(song.artist, 7);
    for (final tag in song.tags) {
      match(tag, 5);
    }
    for (final playlist in song.playlists) {
      match(playlist, 4);
    }

    final terms = query
        .split(RegExp(r'[\s,，。.!！?？、;；:：/\\]+'))
        .where((term) => term.length >= 2);
    final searchable = [
      song.title,
      song.artist,
      ...song.tags,
      ...song.playlists,
    ].join('\u0000').toLowerCase();
    for (final term in terms) {
      if (searchable.contains(term)) score += 2;
    }
    return score;
  }
}
