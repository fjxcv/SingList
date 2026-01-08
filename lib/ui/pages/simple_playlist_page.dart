import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../repository/playlist_repository.dart';
import '../../repository/song_repository.dart';
import '../../state/providers.dart';

class SimplePlaylistPage extends ConsumerStatefulWidget {
  final Playlist playlist;
  const SimplePlaylistPage({super.key, required this.playlist});

  @override
  ConsumerState<SimplePlaylistPage> createState() => _SimplePlaylistPageState();
}

class _SimplePlaylistPageState extends ConsumerState<SimplePlaylistPage> {
  final selectedSongIds = <int>{};
  bool batchMode = false;

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(playlistRepoProvider);
    final songRepo = ref.watch(songRepoProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.playlist.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.playlist_add),
            onPressed: () => _addSongDialog(context, repo, songRepo),
          )
        ],
      ),
      body: StreamBuilder(
        stream: repo.songsInPlaylist(widget.playlist.id),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final songs = snapshot.data!;
          if (songs.isEmpty) return const Center(child: Text('歌单为空'));
          return Column(
            children: [
              if (batchMode)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      FilledButton.tonal(
                        onPressed:
                            selectedSongIds.isEmpty ? null : () => _confirmBatchDelete(context, repo),
                        child: const Text('删除'),
                      ),
                      Text('${selectedSongIds.length} 已选'),
                      TextButton(
                        onPressed: _exitBatchMode,
                        child: const Text('取消'),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  itemCount: songs.length,
                  itemBuilder: (context, index) {
                    final song = songs[index];
                    final checked = selectedSongIds.contains(song.id);
                    return ListTile(
                      leading: batchMode
                          ? Checkbox(
                              value: checked,
                              onChanged: (_) => _toggleSelection(song.id),
                            )
                          : null,
                      title: Text(song.title),
                      subtitle: Text(song.artist),
                      onTap: () => batchMode ? _toggleSelection(song.id) : null,
                      onLongPress: () {
                        if (batchMode) return;
                        setState(() {
                          batchMode = true;
                          selectedSongIds.add(song.id);
                        });
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addSongDialog(
      BuildContext context, PlaylistRepository repo, SongRepository songRepo) async {
    final allSongs = await songRepo.watchAll().first;
    final existing = await repo.songsInPlaylist(widget.playlist.id).first;
    final existingIds = existing.map((s) => s.id).toSet();
    final selectedIds = <int>{};
    String keyword = '';
    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          final candidates = allSongs.where((s) => !existingIds.contains(s.id)).toList();
          final filtered = keyword.isEmpty
              ? candidates
              : candidates
                  .where((s) => s.title.contains(keyword) || s.artist.contains(keyword))
                  .toList();
          final maxListHeight = MediaQuery.of(context).size.height * 0.45;
          return AlertDialog(
            title: const Text('添加歌曲'),
            content: SingleChildScrollView(
              child: Column(
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
                  if (selectedIds.isNotEmpty)
                    Container(
                      width: double.maxFinite,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: selectedIds
                            .map((id) => allSongs.firstWhere((song) => song.id == id))
                            .map(
                              (song) => Chip(
                                label: Text(song.title),
                                onDeleted: () {
                                  setState(() {
                                    selectedIds.remove(song.id);
                                  });
                                },
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.maxFinite,
                    height: maxListHeight,
                    child: filtered.isEmpty
                        ? const Center(child: Text('暂无匹配歌曲'))
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final song = filtered[index];
                              final selected = selectedIds.contains(song.id);
                              return ListTile(
                                title: Text(song.title),
                                subtitle: Text(song.artist),
                                trailing: Icon(selected ? Icons.check_circle : Icons.add),
                                tileColor: selected
                                    ? Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3)
                                    : null,
                                onTap: () {
                                  setState(() {
                                    if (selected) {
                                      selectedIds.remove(song.id);
                                    } else {
                                      selectedIds.add(song.id);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('取消')),
              FilledButton(
                onPressed: selectedIds.isEmpty
                    ? null
                    : () async {
                        await repo.addSongsToPlaylist(widget.playlist.id, selectedIds.toList());
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                      },
                child: const Text('添加'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _toggleSelection(int songId) {
    setState(() {
      if (selectedSongIds.contains(songId)) {
        selectedSongIds.remove(songId);
      } else {
        selectedSongIds.add(songId);
      }
    });
  }

  void _exitBatchMode() {
    setState(() {
      batchMode = false;
      selectedSongIds.clear();
    });
  }

  Future<void> _confirmBatchDelete(BuildContext context, PlaylistRepository repo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除选中的 ${selectedSongIds.length} 首歌曲吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('确认')),
        ],
      ),
    );
    if (confirmed != true) return;
    await repo.removeSongsFromPlaylist(widget.playlist.id, selectedSongIds.toList());
    if (mounted) {
      _exitBatchMode();
    }
  }
}
