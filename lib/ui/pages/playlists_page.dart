import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../repository/playlist_repository.dart';
import '../../state/providers.dart';
import '../../service/kqueue_text_service.dart';
import 'queue_page.dart';
import 'simple_playlist_page.dart';

class PlaylistsPage extends ConsumerStatefulWidget {
  const PlaylistsPage({super.key});

  @override
  ConsumerState<PlaylistsPage> createState() => _PlaylistsPageState();
}

class _PlaylistsPageState extends ConsumerState<PlaylistsPage> {
  final selectedIds = <int>{};
  bool selectionMode = false;

  @override
  Widget build(BuildContext context) {
    final normal = ref.watch(normalPlaylistsProvider);
    final queues = ref.watch(queuePlaylistsProvider);
    final repo = ref.watch(playlistRepoProvider);
    final textService = ref.watch(kqueueTextServiceProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(selectionMode ? '已选 ${selectedIds.length}' : '歌单 / 队列'),
        actions: selectionMode
            ? [
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: '取消选择',
                  onPressed: _exitSelectionMode,
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _createDialog(context, repo),
                ),
                IconButton(
                  icon: const Icon(Icons.content_paste),
                  tooltip: '粘贴导入 KQueue',
                  onPressed: () => _importDialog(context, textService),
                ),
              ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _buildSectionHeader(context, '普通歌单'),
          normal.when(
            data: (items) => Column(
              children: items
                  .map((p) => _buildPlaylistTile(
                        context,
                        repo,
                        p,
                        leading: const Icon(Icons.playlist_play),
                        subtitle: const Text('不重复'),
                        onOpen: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => SimplePlaylistPage(playlist: p)),
                        ),
                      ))
                  .toList(),
            ),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(),
            ),
            error: (e, _) => Text('加载失败 $e'),
          ),
          const SizedBox(height: 8),
          _buildSectionHeader(context, 'KQueue 队列'),
          queues.when(
            data: (items) => Column(
              children: items
                  .map((p) => _buildPlaylistTile(
                        context,
                        repo,
                        p,
                        leading: const Icon(Icons.queue_music),
                        subtitle: const Text('允许重复、可拖拽'),
                        onOpen: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => QueuePage(playlist: p)),
                        ),
                      ))
                  .toList(),
            ),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(),
            ),
            error: (e, _) => Text('加载失败 $e'),
          ),
        ],
      ),
      bottomNavigationBar: selectionMode
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
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FilledButton.tonal(
                        onPressed: selectedIds.isEmpty
                            ? null
                            : () => _confirmBatchDelete(context, repo),
                        child: const Text('删除所选'),
                      ),
                      Text('${selectedIds.length} 已选'),
                      TextButton(
                        onPressed: _exitSelectionMode,
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

  Future<void> _importDialog(
    BuildContext context,
    KQueueTextService textService,
  ) async {
    final controller = TextEditingController();
    String? error;
    var isLoading = false;
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: const Text('粘贴导入 KQueue'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: '粘贴文本',
                    helperText: '每行“歌名 - 歌手”或“歌名/歌手”',
                    helperMaxLines: 2,
                  ),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  )
              ],
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        setState(() {
                          isLoading = true;
                          error = null;
                        });
                        try {
                          final result = await textService.importFromText(controller.text);
                          if (!dialogContext.mounted) return;
                          Navigator.pop(dialogContext);
                          if (result.errorLines.isNotEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('部分行解析失败：${result.errorLines.join(', ')}'),
                              ),
                            );
                          }
                          // ignore: use_build_context_synchronously
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => QueuePage(playlist: result.playlist)),
                          );
                        } catch (e) {
                          setState(() {
                            error = e.toString();
                          });
                        } finally {
                          if (dialogContext.mounted) {
                            setState(() {
                              isLoading = false;
                            });
                          }
                        }
                      },
                child: Text(isLoading ? '导入中...' : '导入并创建'),
              )
            ],
          );
        });
      },
    );
  }

  Future<void> _createDialog(BuildContext context, PlaylistRepository repo) async {
    final nameController = TextEditingController();
    PlaylistType type = PlaylistType.normal;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('创建歌单/队列'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: '名称')),
            const SizedBox(height: 8),
            DropdownButtonFormField<PlaylistType>(
              value: type,
              onChanged: (v) => type = v ?? PlaylistType.normal,
              items: const [
                DropdownMenuItem(value: PlaylistType.normal, child: Text('普通歌单')),
                DropdownMenuItem(value: PlaylistType.kQueue, child: Text('KQueue 队列')),
              ],
            )
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                repo.create(nameController.text.trim(), type);
              }
              Navigator.pop(context);
            },
            child: const Text('创建'),
          )
        ],
      ),
    );
  }

  Future<void> _showPlaylistActions(
    BuildContext context,
    PlaylistRepository repo,
    Playlist playlist,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('编辑歌单名'),
              onTap: () => Navigator.pop(context, 'rename'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('批量删除'),
              onTap: () => Navigator.pop(context, 'batch-delete'),
            ),
          ],
        ),
      ),
    );
    if (action == 'rename' && context.mounted) {
      await _renamePlaylist(context, repo, playlist);
    } else if (action == 'batch-delete') {
      _enterSelectionMode(playlist.id);
    }
  }

  Future<void> _renamePlaylist(
    BuildContext context,
    PlaylistRepository repo,
    Playlist playlist,
  ) async {
    final controller = TextEditingController(text: playlist.name);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑歌单名'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: '名称'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                repo.rename(playlist.id, name);
              }
              Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistTile(
    BuildContext context,
    PlaylistRepository repo,
    Playlist playlist, {
    required Widget leading,
    required Widget subtitle,
    required VoidCallback onOpen,
  }) {
    final isSelected = selectedIds.contains(playlist.id);
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      color:
          isSelected ? theme.colorScheme.surfaceVariant.withOpacity(0.5) : theme.colorScheme.surface,
      child: ListTile(
        leading: leading,
        title: Text(playlist.name, style: theme.textTheme.bodyLarge),
        subtitle: DefaultTextStyle.merge(
          style: theme.textTheme.bodySmall,
          child: subtitle,
        ),
        trailing: selectionMode
            ? Checkbox(
                value: isSelected,
                onChanged: (_) => _toggleSelection(playlist.id),
              )
            : null,
        onTap: () => selectionMode ? _toggleSelection(playlist.id) : onOpen(),
        onLongPress: () => selectionMode
            ? _toggleSelection(playlist.id)
            : _showPlaylistActions(context, repo, playlist),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }

  void _toggleSelection(int playlistId) {
    setState(() {
      if (selectedIds.contains(playlistId)) {
        selectedIds.remove(playlistId);
      } else {
        selectedIds.add(playlistId);
      }
    });
  }

  void _enterSelectionMode(int playlistId) {
    setState(() {
      selectionMode = true;
      selectedIds
        ..clear()
        ..add(playlistId);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      selectionMode = false;
      selectedIds.clear();
    });
  }

  Future<void> _confirmBatchDelete(BuildContext context, PlaylistRepository repo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除选中的 ${selectedIds.length} 个歌单吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('确认')),
        ],
      ),
    );
    if (confirmed != true) return;
    final errors = <String>[];
    for (final id in selectedIds) {
      try {
        await repo.delete(id);
      } catch (e) {
        errors.add(e.toString());
      }
    }
    if (!context.mounted) return;
    if (errors.isNotEmpty) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('操作失败'),
          content: Text('删除失败：${errors.first}'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('知道了')),
          ],
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('删除成功 ${selectedIds.length} 个歌单')),
    );
    _exitSelectionMode();
  }
}
