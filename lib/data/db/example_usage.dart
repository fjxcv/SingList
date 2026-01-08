import 'app_database.dart';

Future<void> exampleUsage(AppDatabase db) async {
  // 确保预置标签存在
  await db.tagDao.ensurePresetTags(['开嗓', '收尾', '合唱']);

  // 歌曲去重写入：已有则返回原 ID
  final songId = await db.songDao.upsertByTitleArtist('稻香', '周杰伦');
  final songId2 = await db.songDao.upsertByTitleArtist('稻香', '周杰伦');
  assert(songId == songId2);

  // 给歌曲打标签
  await db.songTagDao.addTagsToSongs(songIds: [songId], tagIds: [1]);

  // 创建普通歌单并添加歌曲
  final playlistId = await db.playlistDao.createPlaylist('私享歌单', PlaylistType.normal);
  await db.playlistDao.addSongsToPlaylist(playlistId, [songId]);

  // 创建排队歌单（kqueue）并入队
  final queueId = await db.playlistDao.createPlaylist('现场排队', PlaylistType.kQueue);
  await db.queueDao.enqueue(queueId, songId, 0);

  // 查询：模糊搜索、按标签过滤、读取歌单/队列
  final searchResult = await db.songDao.searchSongs('稻');
  final songsWithTag = await db.songTagDao.songsByTag(1).first;
  final playlistSongs = await db.playlistDao.songsInPlaylist(playlistId).first;
  final queueItems = await db.queueDao.queueItemsWithSongs(queueId).first;

  // 仅为展示，避免未使用变量
  assert(searchResult.isNotEmpty && songsWithTag.isNotEmpty);
  assert(playlistSongs.length == 1 && queueItems.length == 1);
}
