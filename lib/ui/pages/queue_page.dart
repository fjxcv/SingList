import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/db/app_database.dart';
import '../../repository/playlist_repository.dart';
import '../../state/providers.dart';
import '../../service/kqueue_text_service.dart';

class QueuePage extends ConsumerWidget {
  final Playlist playlist;
  const QueuePage({super.key, required this.playlist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(playlistRepoProvider);
    final textService = ref.watch(kqueueTextServiceProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(playlist.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            onPressed: () async {
              final text = await textService.exportQueueAsText(playlist.id);
              Share.share(text);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () => _confirmClearQueue(context, repo),
          )
        ],
      ),
      body: StreamBuilder<List<QueueItemWithSong>>(
        stream: repo.queueItems(playlist.id),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final items = snapshot.data!;
          if (items.isEmpty) return const Center(child: Text('队列为空'));
          return ReorderableListView.builder(
            itemCount: items.length,
            onReorder: (oldIndex, newIndex) async {
              final mutable = List.of(items);
              if (newIndex > oldIndex) newIndex -= 1;
              final moved = mutable.removeAt(oldIndex);
              mutable.insert(newIndex, moved);
              await repo.reorderQueue(playlist.id, mutable.map((e) => e.item.id).toList());
            },
            itemBuilder: (context, index) {
              final entry = items[index];
              return ListTile(
                key: ValueKey(entry.item.id),
                title: Text(entry.song.title),
                subtitle: Text(entry.song.artist),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => _confirmRemoveItem(context, repo, entry.item.id),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmClearQueue(BuildContext context, PlaylistRepository repo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清空'),
        content: const Text('确定要清空该队列吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('确认')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await repo.clearQueue(playlist.id);
    } catch (e) {
      if (!context.mounted) return;
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('操作失败'),
          content: Text('清空失败：$e'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('知道了')),
          ],
        ),
      );
    }
  }

  Future<void> _confirmRemoveItem(
    BuildContext context,
    PlaylistRepository repo,
    int itemId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除此歌曲吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('确认')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await repo.removeQueueItem(itemId);
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
}
