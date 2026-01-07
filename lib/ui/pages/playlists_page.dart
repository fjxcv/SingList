import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../repository/playlist_repository.dart';
import '../../state/providers.dart';
import '../../service/kqueue_text_service.dart';
import 'queue_page.dart';
import 'simple_playlist_page.dart';

class PlaylistsPage extends ConsumerWidget {
  const PlaylistsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final normal = ref.watch(normalPlaylistsProvider);
    final queues = ref.watch(queuePlaylistsProvider);
    final repo = ref.watch(playlistRepoProvider);
    final textService = ref.watch(kqueueTextServiceProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('歌单 / 队列'),
        actions: [
          IconButton(
            icon: const Icon(Icons.content_paste),
            tooltip: '粘贴导入 KQueue',
            onPressed: () => _importDialog(context, textService),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _createDialog(context, repo),
          )
        ],
      ),
      body: ListView(
        children: [
          const ListTile(title: Text('普通歌单')),
          normal.when(
            data: (items) => Column(
              children: items
                  .map((p) => ListTile(
                        leading: const Icon(Icons.playlist_play),
                        title: Text(p.name),
                        subtitle: const Text('不重复'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _confirmDeletePlaylist(context, repo, p),
                        ),
                        onLongPress: () => _showPlaylistActions(context, repo, p),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => SimplePlaylistPage(playlist: p)),
                        ),
                      ))
                  .toList(),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => ListTile(title: Text('加载失败 $e')),
          ),
          const ListTile(title: Text('KQueue 队列')),
          queues.when(
            data: (items) => Column(
              children: items
                  .map((p) => ListTile(
                        leading: const Icon(Icons.queue_music),
                        title: Text(p.name),
                        subtitle: const Text('允许重复、可拖拽'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _confirmDeletePlaylist(context, repo, p),
                        ),
                        onLongPress: () => _showPlaylistActions(context, repo, p),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => QueuePage(playlist: p)),
                        ),
                      ))
                  .toList(),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => ListTile(title: Text('加载失败 $e')),
          ),
        ],
      ),
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
                    labelText: '粘贴文本，每行“歌名 - 歌手”或“歌名/歌手”',
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

  Future<void> _confirmDeletePlaylist(
    BuildContext context,
    PlaylistRepository repo,
    Playlist playlist,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除“${playlist.name}”吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('确认')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await repo.delete(playlist.id);
    } catch (e) {
      if (!context.mounted) return;
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('操作失败'),
          content: Text('删除失败：$e'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('知道了')),
          ],
        ),
      );
    }
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
          ],
        ),
      ),
    );
    if (action == 'rename' && context.mounted) {
      await _renamePlaylist(context, repo, playlist);
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
}
