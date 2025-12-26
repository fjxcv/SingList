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
    int? selectedId;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加歌曲'),
        content: DropdownButtonFormField<int>(
          items: allSongs.map((s) => DropdownMenuItem(value: s.id, child: Text('${s.title} - ${s.artist}'))).toList(),
          onChanged: (v) => selectedId = v,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              if (selectedId != null) {
                repo.addSongsToPlaylist(playlist.id, [selectedId!]);
              }
              Navigator.pop(context);
            },
            child: const Text('添加'),
          )
        ],
      ),
    );
  }
}
