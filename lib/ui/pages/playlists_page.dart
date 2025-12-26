import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../repository/playlist_repository.dart';
import '../../state/providers.dart';
import 'queue_page.dart';
import 'simple_playlist_page.dart';

class PlaylistsPage extends ConsumerWidget {
  const PlaylistsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final normal = ref.watch(normalPlaylistsProvider);
    final queues = ref.watch(queuePlaylistsProvider);
    final repo = ref.watch(playlistRepoProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('歌单 / 队列'),
        actions: [
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
                          onPressed: () => repo.delete(p.id),
                        ),
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
                          onPressed: () => repo.delete(p.id),
                        ),
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
}
