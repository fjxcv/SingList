import '../data/db/app_database.dart';
import '../repository/playlist_repository.dart';
import '../repository/song_repository.dart';
import 'ai_playlist_models.dart';

class AiPlaylistSaveException implements Exception {
  const AiPlaylistSaveException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AiPlaylistSaveService {
  const AiPlaylistSaveService({
    required this.songRepository,
    required this.playlistRepository,
  });

  final SongRepository songRepository;
  final PlaylistRepository playlistRepository;

  Future<AiPlaylistSaveResult> createNormal({
    required String name,
    required List<int> orderedSongIds,
  }) async {
    final valid = await _validSongIds(orderedSongIds);
    final playlist = await playlistRepository.createNormalWithSongs(
      _requiredName(name),
      valid.ids,
    );
    return AiPlaylistSaveResult(
      playlistId: playlist.id,
      savedSongIds: valid.ids,
      filteredMissingCount: valid.filteredCount,
    );
  }

  Future<AiPlaylistSaveResult> createQueue({
    required String name,
    required List<int> orderedSongIds,
  }) async {
    final valid = await _validSongIds(orderedSongIds);
    final playlist = await playlistRepository.createQueueWithSongsNamed(
      _requiredName(name),
      valid.ids,
    );
    return AiPlaylistSaveResult(
      playlistId: playlist.id,
      savedSongIds: valid.ids,
      filteredMissingCount: valid.filteredCount,
    );
  }

  Future<AiPlaylistSaveResult> addToExisting({
    required int playlistId,
    required PlaylistType type,
    required List<int> orderedSongIds,
  }) async {
    final playlist = await playlistRepository.findById(playlistId);
    if (playlist == null || playlist.type != type) {
      throw const AiPlaylistSaveException('目标歌单已不存在或类型不正确');
    }
    final valid = await _validSongIds(orderedSongIds);
    if (type == PlaylistType.normal) {
      await playlistRepository.addSongsToPlaylist(playlistId, valid.ids);
    } else {
      await playlistRepository.appendSongsToQueue(playlistId, valid.ids);
    }
    return AiPlaylistSaveResult(
      playlistId: playlistId,
      savedSongIds: valid.ids,
      filteredMissingCount: valid.filteredCount,
    );
  }

  String _requiredName(String value) {
    final name = value.trim();
    if (name.isEmpty) {
      throw const AiPlaylistSaveException('歌单名称不能为空');
    }
    return name;
  }

  Future<_ValidSongIds> _validSongIds(List<int> orderedSongIds) async {
    final deduplicated = <int>[];
    final seen = <int>{};
    for (final id in orderedSongIds) {
      if (seen.add(id)) deduplicated.add(id);
    }
    final existing = await songRepository.findByIds(deduplicated);
    final existingIds = existing.map((song) => song.id).toSet();
    final valid = deduplicated.where(existingIds.contains).toList();
    if (valid.isEmpty) {
      throw const AiPlaylistSaveException(
        '所选歌曲已不存在，未创建或修改任何歌单',
      );
    }
    return _ValidSongIds(
      ids: valid,
      filteredCount: deduplicated.length - valid.length,
    );
  }
}

class _ValidSongIds {
  const _ValidSongIds({
    required this.ids,
    required this.filteredCount,
  });

  final List<int> ids;
  final int filteredCount;
}
