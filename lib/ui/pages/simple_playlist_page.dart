import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../repository/playlist_repository.dart';
import '../../repository/song_repository.dart';
import '../../state/providers.dart';

class SimplePlaylistPage extends ConsumerWidget {
  final Playlist playlist;
  const SimplePlaylistPage({super.key, required this.playlist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(playlistRepoProvider);
    final songRepo = ref.watch(songRepoProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(playlist.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.playlist_add),
            onPressed: () => _addSongDialog(context, repo, songRepo),
          )
        ],
      ),
      body: StreamBuilder(
        stream: repo.songsInPlaylist(playlist.id),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final songs = snapshot.data!;
          if (songs.isEmpty) return const Center(child: Text('歌单为空'));
          return ListView.builder(
            itemCount: songs.length,
            itemBuilder: (context, index) {
              final song = songs[index];
              return ListTile(
                title: Text(song.title),
                subtitle: Text(song.artist),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _addSongDialog(
      BuildContext context, PlaylistRepository repo, SongRepository songRepo) async {
    final allSongs = await songRepo.watchAll().first;
    String keyword = '';
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final filtered = keyword.isEmpty
              ? allSongs
              : allSongs
                  .where((s) => s.title.contains(keyword) || s.artist.contains(keyword))
                  .toList();
          return AlertDialog(
            title: const Text('添加歌曲'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: '搜索歌曲',
                  ),
                  onChanged: (value) => setState(() => keyword = value),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.maxFinite,
                  height: 300,
                  child: filtered.isEmpty
                      ? const Center(child: Text('暂无匹配歌曲'))
                      : ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final song = filtered[index];
                            return ListTile(
                              title: Text(song.title),
                              subtitle: Text(song.artist),
                              trailing: const Icon(Icons.add),
                              onTap: () {
                                repo.addSongsToPlaylist(playlist.id, [song.id]);
                                Navigator.pop(context);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
            ],
          );
        },
      ),
    );
  }
}
