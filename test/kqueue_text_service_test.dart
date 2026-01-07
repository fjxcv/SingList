import 'package:flutter_test/flutter_test.dart';
import 'package:sing_list/data/db/app_database.dart';
import 'package:sing_list/repository/playlist_repository.dart';
import 'package:sing_list/repository/song_repository.dart';
import 'package:sing_list/service/kqueue_text_service.dart';
import 'package:sing_list/service/normalize.dart';

class FakeSongRepository implements SongRepository {
  final Map<int, Song> _songs = {};
  final Map<String, int> _byKey = {};
  int _id = 1;

  @override
  AppDatabase get db => throw UnimplementedError();

  Song songById(int id) => _songs[id]!;

  @override
  Future<int> upsertByTitleArtist(String title, String artist) async {
    final key = '${normalizeTitle(title)}|${normalizeArtist(artist)}';
    final existing = _byKey[key];
    if (existing != null) return existing;
    final song = Song(
      id: _id++,
      title: title,
      artist: artist,
      titleNorm: normalizeTitle(title),
      artistNorm: normalizeArtist(artist),
      createdAt: DateTime.now(),
    );
    _songs[song.id] = song;
    _byKey[key] = song.id;
    return song.id;
  }

  @override
  Future<void> addTagsToSongs({required List<int> songIds, required List<int> tagIds}) =>
      throw UnimplementedError();
  @override
  Future<void> deleteSong(int id) => throw UnimplementedError();
  @override
  Future<List<Song>> fetchAllSortedByNorm() => throw UnimplementedError();
  @override
  Future<List<Song>> fetchSongsByTagSorted(int tagId) => throw UnimplementedError();
  @override
  Stream<List<Song>> songsByTag(int tagId) => throw UnimplementedError();
  @override
  Future<List<Song>> search(String keyword) => throw UnimplementedError();
  @override
  Stream<List<Song>> watchAll({String keyword = ''}) => throw UnimplementedError();
  @override
  Future<void> updateSong(int id, String title, String artist) => throw UnimplementedError();
  @override
  Future<void> removeTagsFromSongs({required List<int> songIds, required List<int> tagIds}) =>
      throw UnimplementedError();

  @override
  Future<SongUpsertResult> addSong(String title, String artist) async {
    final key = '${normalizeTitle(title)}|${normalizeArtist(artist)}';
    if (_byKey.containsKey(key)) {
      return SongUpsertResult.existed;
    }
    final song = Song(
      id: _id++,
      title: title,
      artist: artist,
      titleNorm: normalizeTitle(title),
      artistNorm: normalizeArtist(artist),
      createdAt: DateTime.now(),
    );
    _songs[song.id] = song;
    _byKey[key] = song.id;
    return SongUpsertResult.created;
  }
}

class FakePlaylistRepository implements PlaylistRepository {
  FakePlaylistRepository(this.songRepository);

  final FakeSongRepository songRepository;
  final Map<int, List<QueueItemWithSong>> _queues = {};
  int _playlistId = 1;
  int _queueItemId = 1;

  @override
  AppDatabase get db => throw UnimplementedError();

  @override
  Future<Playlist> createQueueWithSongs(List<int> songIds) async {
    final playlist = Playlist(
      id: _playlistId++,
      name: 'KQueue ${DateTime.now().toIso8601String()}',
      type: PlaylistType.kQueue,
      createdAt: DateTime.now(),
    );
    final items = <QueueItemWithSong>[];
    for (var i = 0; i < songIds.length; i++) {
      final item = QueueItem(
        id: _queueItemId++,
        playlistId: playlist.id,
        songId: songIds[i],
        position: i,
      );
      items.add(QueueItemWithSong(item: item, song: songRepository.songById(songIds[i])));
    }
    _queues[playlist.id] = items;
    return playlist;
  }

  @override
  Stream<List<QueueItemWithSong>> queueItems(int playlistId) {
    return Stream.value(_queues[playlistId] ?? []);
  }

  @override
  Future<void> clearQueue(int playlistId) => throw UnimplementedError();
  @override
  Future<int> create(String name, PlaylistType type) => throw UnimplementedError();
  @override
  Future<void> delete(int id) => throw UnimplementedError();
  @override
  Future<Playlist?> findById(int id) => throw UnimplementedError();
  @override
  Future<int> enqueue(int playlistId, int songId, int position) => throw UnimplementedError();
  @override
  Future<void> reorderQueue(int playlistId, List<int> itemIdsInOrder) => throw UnimplementedError();
  @override
  Stream<List<Song>> songsInPlaylist(int playlistId) => throw UnimplementedError();
  @override
  Future<List<Song>> songsInPlaylistSortedByNorm(int playlistId) => throw UnimplementedError();
  @override
  Stream<List<Playlist>> watchByType(PlaylistType type) => throw UnimplementedError();
  @override
  Future<void> addSongsToPlaylist(int playlistId, List<int> songIds) => throw UnimplementedError();

  @override
  Future<void> removeQueueItem(int id) {
    throw UnimplementedError();
  }
}

void main() {
  test('importFromText creates queue with duplicates and error lines', () async {
    final songRepo = FakeSongRepository();
    final playlistRepo = FakePlaylistRepository(songRepo);
    final service = KQueueTextService(songRepo, playlistRepo);

    final result = await service.importFromText('#K歌歌单\nHello - Singer\nHello - Singer\nBad Line\nNice/Singer2');

    expect(result.errorLines, ['Bad Line']);
    final items = await playlistRepo.queueItems(result.playlist.id).first;
    expect(items.length, 3);
    expect(items[0].song.title, 'Hello');
    expect(items[1].song.title, 'Hello');
    expect(items[0].item.songId, items[1].item.songId);
    expect(items[2].song.artist, 'Singer2');
  });

  test('exportQueueAsText outputs title and songs', () async {
    final songRepo = FakeSongRepository();
    final playlistRepo = FakePlaylistRepository(songRepo);
    final service = KQueueTextService(songRepo, playlistRepo);

    final playlist = await playlistRepo.createQueueWithSongs([
      await songRepo.upsertByTitleArtist('Song1', 'Artist1'),
      await songRepo.upsertByTitleArtist('Song2', 'Artist2'),
    ]);

    final text = await service.exportQueueAsText(playlist.id);
    expect(text.trim(), '#K歌歌单\nSong1 - Artist1\nSong2 - Artist2');
  });
}
