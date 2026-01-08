import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../repository/playlist_repository.dart';
import '../../repository/song_repository.dart';
import '../../repository/tag_repository.dart';
import '../../state/providers.dart';
import '../../data/db/app_database.dart';

class SongsPage extends ConsumerStatefulWidget {
  const SongsPage({super.key});

  @override
  ConsumerState<SongsPage> createState() => _SongsPageState();
}

class _SongsPageState extends ConsumerState<SongsPage> {
  String keyword = '';
  final selectedIds = <int>{};
  final selectionOrder = <int>[];
  bool batchMode = false;

  @override
  Widget build(BuildContext context) {
    final songsAsync = ref.watch(songsProvider);
    final repo = ref.watch(songRepoProvider);
    final totalCount = songsAsync.maybeWhen(data: (songs) => songs.length, orElse: () => null);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          batchMode
              ? '已选 ${selectedIds.length}'
              : '歌曲库${totalCount == null ? '' : ' ($totalCount)'}',
        ),
        actions: batchMode
            ? [
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: '取消选择',
                  onPressed: _exitBatchMode,
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _showAddDialog(context, repo),
                ),
                IconButton(
                  icon: const Icon(Icons.content_paste),
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
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final song = list[index];
              final checked = selectedIds.contains(song.id);
              final theme = Theme.of(context);
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                color: checked
                    ? theme.colorScheme.surfaceVariant.withOpacity(0.5)
                    : theme.colorScheme.surface,
                child: ListTile(
                  title: Text(song.title, style: theme.textTheme.bodyLarge),
                  subtitle: Text(song.artist, style: theme.textTheme.bodySmall),
                  trailing: batchMode
                      ? Checkbox(
                          value: checked,
                          onChanged: (_) => _toggleSelection(song.id),
                        )
                      : null,
                  onTap: () => batchMode ? _toggleSelection(song.id) : _editDialog(context, repo, song),
                  onLongPress: () =>
                      batchMode ? _toggleSelection(song.id) : _showSongActions(context, repo, song),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
      ),
      bottomNavigationBar: batchMode
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FilledButton.tonal(
                        onPressed: selectedIds.isEmpty
                            ? null
                            : () => _addTags(context, selectionOrder.toList()),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 32),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        child: const Text('加标签'),
                      ),
                      FilledButton.tonal(
                        onPressed: selectedIds.isEmpty
                            ? null
                            : () => _addToPlaylist(context, selectionOrder.toList()),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 32),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        child: const Text('加入歌单'),
                      ),
                      FilledButton.tonal(
                        onPressed:
                            selectedIds.isEmpty ? null : () => _confirmBatchDelete(context, repo),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 32),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        child: const Text('删除'),
                      ),
                      Text('${selectedIds.length} 已选'),
                      TextButton(
                        onPressed: _exitBatchMode,
                        child: const Text('取消'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : null,
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

  void _toggleSelection(int songId) {
    setState(() {
      if (selectedIds.contains(songId)) {
        selectedIds.remove(songId);
        selectionOrder.remove(songId);
      } else {
        selectedIds.add(songId);
        selectionOrder.add(songId);
      }
    });
  }

  void _exitBatchMode() {
    setState(() {
      batchMode = false;
      selectedIds.clear();
      selectionOrder.clear();
    });
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

  Future<void> _addTags(BuildContext context, List<int> songIds) async {
    final tagRepo = ref.read(tagRepoProvider);
    final tagsAsync = await tagRepo.watchAll().first;
    if (tagsAsync.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('暂无标签可选')),
        );
      }
      return;
    }
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
                tagRepo.attachSongs(selectedTagId!, songIds);
              }
              Navigator.pop(context);
            },
            child: const Text('确认'),
          )
        ],
      ),
    );
  }

  Future<void> _addToPlaylist(BuildContext context, List<int> songIds) async {
    final playlistRepo = ref.read(playlistRepoProvider);
    final normalPlaylists = await playlistRepo.watchByType(PlaylistType.normal).first;
    final queuePlaylists = await playlistRepo.watchByType(PlaylistType.kQueue).first;
    if (normalPlaylists.isEmpty && queuePlaylists.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('暂无可加入的歌单')),
        );
      }
      return;
    }
    int? selectedPlaylistId;
    PlaylistType selectedType = PlaylistType.normal;
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final playlists = selectedType == PlaylistType.normal ? normalPlaylists : queuePlaylists;
          return AlertDialog(
            title: const Text('加入歌单'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<PlaylistType>(
                  value: selectedType,
                  items: const [
                    DropdownMenuItem(value: PlaylistType.normal, child: Text('普通歌单')),
                    DropdownMenuItem(value: PlaylistType.kQueue, child: Text('KQueue 队列')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setDialogState(() {
                      selectedType = v;
                      selectedPlaylistId = null;
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  items: playlists.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                  onChanged: (v) => selectedPlaylistId = v,
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
              FilledButton(
                onPressed: () async {
                  if (selectedPlaylistId != null) {
                    await _handleAddToPlaylist(
                      playlistRepo,
                      selectedPlaylistId!,
                      selectedType,
                      songIds,
                    );
                  }
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                },
                child: const Text('加入'),
              )
            ],
          );
        },
      ),
    );
  }

  Future<void> _handleAddToPlaylist(
    PlaylistRepository repo,
    int playlistId,
    PlaylistType type,
    List<int> songIds,
  ) async {
    if (type == PlaylistType.normal) {
      await repo.addSongsToPlaylist(playlistId, songIds);
      return;
    }
    final existing = await repo.queueItems(playlistId).first;
    var position = existing.length;
    for (final songId in songIds) {
      await repo.enqueue(playlistId, songId, position);
      position += 1;
    }
  }

  Future<void> _showSongActions(BuildContext context, SongRepository repo, Song song) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('编辑歌曲'),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('删除歌曲'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
            ListTile(
              leading: const Icon(Icons.label_outline),
              title: const Text('添加标签'),
              onTap: () => Navigator.pop(context, 'tag'),
            ),
            ListTile(
              leading: const Icon(Icons.queue_music),
              title: const Text('加入歌单'),
              onTap: () => Navigator.pop(context, 'playlist'),
            ),
            ListTile(
              leading: const Icon(Icons.select_all),
              title: const Text('批量操作'),
              onTap: () => Navigator.pop(context, 'batch'),
            ),
          ],
        ),
      ),
    );
    if (action == null) return;
    if (action == 'edit') {
      await _editDialog(context, repo, song);
    } else if (action == 'delete') {
      await _confirmDelete(context, repo, [song.id]);
    } else if (action == 'tag') {
      await _addTags(context, [song.id]);
    } else if (action == 'playlist') {
      await _addToPlaylist(context, [song.id]);
    } else if (action == 'batch') {
      setState(() {
        batchMode = true;
        selectedIds
          ..clear()
          ..add(song.id);
        selectionOrder
          ..clear()
          ..add(song.id);
      });
    }
  }

  Future<void> _confirmBatchDelete(BuildContext context, SongRepository repo) async {
    await _confirmDelete(context, repo, selectionOrder.toList(), showCountDialog: true);
  }

  Future<void> _confirmDelete(
    BuildContext context,
    SongRepository repo,
    List<int> songIds, {
    bool showCountDialog = false,
  }) async {
    final confirmed = await _showConfirmDialog(
      context,
      title: '确认删除',
      message: '确定要删除选中的歌曲吗？',
    );
    if (!confirmed) return;
    int successCount = 0;
    final errors = <String>[];
    for (final id in songIds) {
      try {
        await repo.deleteSong(id);
        successCount += 1;
      } catch (e) {
        errors.add(e.toString());
      }
    }
    if (errors.isNotEmpty) {
      if (context.mounted) {
        await _showErrorDialog(context, '删除失败：${errors.first}');
      }
    }
    if (showCountDialog && context.mounted) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('删除完成'),
          content: Text('成功删除 $successCount 首歌曲'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('知道了')),
          ],
        ),
      );
      _exitBatchMode();
    }
  }

  Future<bool> _showConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('确认')),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _showErrorDialog(BuildContext context, String message) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('操作失败'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('知道了')),
        ],
      ),
    );
  }
}
