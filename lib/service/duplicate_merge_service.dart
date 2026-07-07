import 'package:drift/drift.dart';

import '../data/db/app_database.dart';
import '../repository/song_repository.dart';

class DuplicateSongEntry {
  const DuplicateSongEntry({
    required this.song,
    required this.tagCount,
    required this.playlistCount,
    required this.queueCount,
  });

  final Song song;
  final int tagCount;
  final int playlistCount;
  final int queueCount;
}

class DuplicateGroup {
  const DuplicateGroup({
    required this.key,
    required this.entries,
  });

  final String key;
  final List<DuplicateSongEntry> entries;
}

class DuplicateMergeService {
  DuplicateMergeService(this.db, this.songRepo);

  final AppDatabase db;
  final SongRepository songRepo;

  Future<int> _countForSong(String table, int songId) async {
    final row = await db.customSelect(
      'SELECT COUNT(*) AS c FROM $table WHERE song_id = ?',
      variables: [Variable<int>(songId)],
      readsFrom: {},
    ).getSingle();
    return row.read<int>('c');
  }

  Future<List<DuplicateGroup>> findDuplicateGroups() async {
    final songs = await db.songDao.fetchAllSortedByNorm();
    final grouped = <String, List<Song>>{};
    for (final song in songs) {
      final key = '${song.titleNorm}|${song.artistNorm}';
      grouped.putIfAbsent(key, () => []).add(song);
    }

    final result = <DuplicateGroup>[];
    for (final entry in grouped.entries) {
      if (entry.value.length < 2) continue;
      final entries = <DuplicateSongEntry>[];
      for (final song in entry.value) {
        entries.add(DuplicateSongEntry(
          song: song,
          tagCount: await _countForSong('song_tags', song.id),
          playlistCount: await _countForSong('playlist_songs', song.id),
          queueCount: await _countForSong('queue_items', song.id),
        ));
      }
      result.add(DuplicateGroup(key: entry.key, entries: entries));
    }
    return result;
  }

  Future<void> mergeGroup(DuplicateGroup group, int keepSongId) async {
    final toRemove = group.entries.map((e) => e.song.id).where((id) => id != keepSongId).toList();
    for (final removeId in toRemove) {
      await _reassignReferences(fromId: removeId, toId: keepSongId);
      await songRepo.deleteSong(removeId);
    }
  }

  Future<void> _reassignReferences({required int fromId, required int toId}) async {
    await db.transaction(() async {
      final tagRows = await db.customSelect(
        'SELECT tag_id FROM song_tags WHERE song_id = ?',
        variables: [Variable<int>(fromId)],
        readsFrom: {},
      ).get();
      for (final row in tagRows) {
        await db.songTagDao.addTagsToSongs(
          songIds: [toId],
          tagIds: [row.read<int>('tag_id')],
        );
      }

      final playlistRows = await db.customSelect(
        'SELECT playlist_id FROM playlist_songs WHERE song_id = ?',
        variables: [Variable<int>(fromId)],
        readsFrom: {},
      ).get();
      for (final row in playlistRows) {
        await db.playlistDao.addSongsToPlaylist(row.read<int>('playlist_id'), [toId]);
      }

      final queueRows = await db.customSelect(
        'SELECT playlist_id, position FROM queue_items WHERE song_id = ?',
        variables: [Variable<int>(fromId)],
        readsFrom: {},
      ).get();
      for (final row in queueRows) {
        await db.queueDao.enqueue(
          row.read<int>('playlist_id'),
          toId,
          row.read<int>('position'),
        );
      }
    });
  }
}
