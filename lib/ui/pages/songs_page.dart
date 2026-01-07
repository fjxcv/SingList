import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../repository/playlist_repository.dart';
import '../../repository/song_repository.dart';
import '../../repository/tag_repository.dart';
import '../../service/normalize.dart';
import '../../state/providers.dart';
import '../../data/db/app_database.dart';

class SongsPage extends ConsumerStatefulWidget {
  const SongsPage({super.key});

  @override
  ConsumerState<SongsPage> createState() => _SongsPageState();
}

class _SongsPageState extends ConsumerState<SongsPage> {
  String keyword = '';
  final selected = <int>{};

  @override
  Widget build(BuildContext context) {
    final songsAsync = ref.watch(songsProvider);
    final repo = ref.watch(songRepoProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('歌曲库'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddDialog(context, repo),
          ),
          IconButton(
            icon: const Icon(Icons.upload),
            onPressed: () => _showBulkImportDialog(context, repo),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: '按歌名/歌手搜索'),
              onChanged: (v) => setState(() => keyword = v),
            ),
          ),
        ),
      ),
      body: songsAsync.when(
        data: (songs) {
          final list = keyword.isEmpty
              ? songs
              : songs.where((s) => s.title.contains(keyword) || s.artist.contains(keyword)).toList();
          if (list.isEmpty) {
            return const Center(child: Text('暂无歌曲，点击右上角新增'));
          }
          return Column(
            children: [
              if (selected.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      FilledButton.tonal(
                        onPressed: () => _addTags(context),
                        child: const Text('批量加标签'),
                      ),
                      FilledButton.tonal(
                        onPressed: () => _addToPlaylist(context),
                        child: const Text('加入普通歌单'),
                      ),
                      Text('${selected.length} 已选'),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final song = list[index];
                    final checked = selected.contains(song.id);
                    return ListTile(
                      leading: Checkbox(
                        value: checked,
                        onChanged: (_) {
                          setState(() {
                            if (checked) {
                              selected.remove(song.id);
                            } else {
                              selected.add(song.id);
                            }
                          });
                        },
                      ),
                      title: Text(song.title),
                      subtitle: Text(song.artist),
                      onTap: () => _editDialog(context, repo, song),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => repo.deleteSong(song.id),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
      ),
    );
  }

  Future<void> _showAddDialog(BuildContext context, SongRepository repo) async {
    final titleController = TextEditingController();
    final artistController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新增歌曲'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleController, decoration: const InputDecoration(labelText: '歌名')),
            const SizedBox(height: 12),
            TextField(controller: artistController, decoration: const InputDecoration(labelText: '歌手')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              final result = await repo.addSong(titleController.text, artistController.text);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result == SongUpsertResult.created ? '添加成功' : '歌曲已存在'),
                  ),
                );
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Future<void> _showBulkImportDialog(BuildContext context, SongRepository repo) async {
    final textController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('批量导入'),
        content: TextField(
          controller: textController,
          maxLines: 10,
          decoration: const InputDecoration(
            hintText: '每行一首，支持格式：\n歌名 - 歌手\n歌名-歌手\n歌名，歌手\n歌名,歌手\n歌名 歌手',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              final lines = textController.text.split('\n');
              int successCount = 0;
              List<String> errorLines = [];

              for (final line in lines) {
                if (line.trim().isEmpty) continue;

                final parts = _parseSongLine(line);
                if (parts == null) {
                  errorLines.add(line);
                  continue;
                }

                final result = await repo.addSong(parts[0], parts[1]);
                if (result == SongUpsertResult.created) {
                  successCount++;
                }
              }

              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('导入完成：$successCount 首成功，${errorLines.length} 行失败'),
                  ),
                );
              }
            },
            child: const Text('导入'),
          ),
        ],
      ),
    );
  }

  List<String>? _parseSongLine(String line) {
    const delimiters = [' - ', '-', ' – ', '–', '—', '，', ',', ' '];

    for (var delimiter in delimiters) {
      final index = line.lastIndexOf(delimiter);

      if (index > 0 && index < line.length - 1) {
        final title = line.substring(0, index).trim();
        final artist = line.substring(index + delimiter.length).trim();

        if (title.isNotEmpty) {
          return [title, artist];
        }
      }
    }

    if (line.trim().isNotEmpty) {
      return [line.trim(), ''];
    }

    return null;
  }

  Future<void> _editDialog(BuildContext context, SongRepository repo, Song song) async {
    final titleController = TextEditingController(text: song.title);
    final artistController = TextEditingController(text: song.artist);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑歌曲'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleController, decoration: const InputDecoration(labelText: '歌名')),
            const SizedBox(height: 12),
            TextField(controller: artistController, decoration: const InputDecoration(labelText: '歌手')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              repo.updateSong(song.id, titleController.text, artistController.text);
              Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Future<void> _addTags(BuildContext context) async {
    final tagRepo = ref.read(tagRepoProvider);
    final tagsAsync = await tagRepo.watchAll().first;
    int? selectedTagId;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择标签'),
        content: DropdownButtonFormField<int>(
          items: tagsAsync.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))).toList(),
          onChanged: (v) => selectedTagId = v,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              if (selectedTagId != null) {
                tagRepo.attachSongs(selectedTagId!, selected.toList());
              }
              Navigator.pop(context);
            },
            child: const Text('确认'),
          )
        ],
      ),
    );
  }

  Future<void> _addToPlaylist(BuildContext context) async {
    final playlistRepo = ref.read(playlistRepoProvider);
    final playlists = await playlistRepo.watchByType(PlaylistType.normal).first;
    int? selectedPlaylistId;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('加入歌单'),
        content: DropdownButtonFormField<int>(
          items: playlists.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
          onChanged: (v) => selectedPlaylistId = v,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              if (selectedPlaylistId != null) {
                playlistRepo.addSongsToPlaylist(selectedPlaylistId!, selected.toList());
              }
              Navigator.pop(context);
            },
            child: const Text('加入'),
          )
        ],
      ),
    );
  }
}
