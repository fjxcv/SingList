import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sing_list/ai_playlist/ai_playlist_save_service.dart';
import 'package:sing_list/data/db/app_database.dart';
import 'package:sing_list/repository/playlist_repository.dart';
import 'package:sing_list/repository/song_repository.dart';

void main() {
  late AppDatabase database;
  late SongRepository songs;
  late PlaylistRepository playlists;
  late AiPlaylistSaveService service;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    songs = SongRepository(database);
    playlists = PlaylistRepository(database);
    service = AiPlaylistSaveService(
      songRepository: songs,
      playlistRepository: playlists,
    );
  });

  tearDown(() => database.close());

  Future<List<int>> createSongs(int count) async {
    final ids = <int>[];
    for (var index = 0; index < count; index++) {
      ids.add(await songs.upsertByTitleArtist('Song $index', 'Artist'));
    }
    return ids;
  }

  test('does not change database before save is invoked', () async {
    await createSongs(2);

    expect(await playlists.fetchByType(PlaylistType.normal), isEmpty);
    expect(await playlists.fetchByType(PlaylistType.kQueue), isEmpty);
  });

  test('creates normal playlist atomically and deduplicates songs', () async {
    final ids = await createSongs(2);
    final result = await service.createNormal(
      name: 'AI 歌单',
      orderedSongIds: [ids[0], ids[0], ids[1]],
    );
    final saved = await playlists.songsInPlaylist(result.playlistId).first;

    expect(saved.map((song) => song.id), ids);
    expect(
      (await playlists.findById(result.playlistId))?.type,
      PlaylistType.normal,
    );
  });

  test('creates KQueue in adjusted recommendation order', () async {
    final ids = await createSongs(3);
    final order = [ids[2], ids[0], ids[1]];
    final result = await service.createQueue(
      name: 'AI KQueue',
      orderedSongIds: order,
    );
    final items = await playlists.queueItems(result.playlistId).first;

    expect(items.map((item) => item.song.id), order);
  });

  test('filters deleted songs immediately before save', () async {
    final ids = await createSongs(2);
    await songs.deleteSong(ids[1]);
    final result = await service.createNormal(
      name: '仍可创建',
      orderedSongIds: ids,
    );

    expect(result.savedSongIds, [ids[0]]);
    expect(result.filteredMissingCount, 1);
  });

  test('refuses to create an empty playlist when all songs disappeared',
      () async {
    final ids = await createSongs(1);
    await songs.deleteSong(ids.single);

    await expectLater(
      service.createNormal(name: '不能创建', orderedSongIds: ids),
      throwsA(isA<AiPlaylistSaveException>()),
    );
    expect(await playlists.fetchByType(PlaylistType.normal), isEmpty);
  });

  test('adds to existing normal playlist without duplicates', () async {
    final ids = await createSongs(2);
    final playlistId = await playlists.create('已有歌单', PlaylistType.normal);
    await playlists.addSongsToPlaylist(playlistId, [ids[0]]);

    await service.addToExisting(
      playlistId: playlistId,
      type: PlaylistType.normal,
      orderedSongIds: [ids[0], ids[1]],
    );
    final saved = await playlists.songsInPlaylist(playlistId).first;

    expect(saved.map((song) => song.id), ids);
  });

  test('appends to existing KQueue in recommendation order', () async {
    final ids = await createSongs(3);
    final queue = await playlists.createQueueWithSongs([ids[0]]);

    await service.addToExisting(
      playlistId: queue.id,
      type: PlaylistType.kQueue,
      orderedSongIds: [ids[2], ids[1]],
    );
    final items = await playlists.queueItems(queue.id).first;

    expect(items.map((item) => item.song.id), [ids[0], ids[2], ids[1]]);
  });

  test('transaction rolls back playlist name when inserting a bad id',
      () async {
    await expectLater(
      playlists.createNormalWithSongs('不应遗留', [999]),
      throwsA(anything),
    );

    expect(await playlists.fetchByType(PlaylistType.normal), isEmpty);
  });
}
