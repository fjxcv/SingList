import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/db/app_database.dart';
import '../../repository/playlist_repository.dart';
import '../../state/providers.dart';

class QueuePage extends ConsumerWidget {
  final Playlist playlist;
  const QueuePage({super.key, required this.playlist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(playlistRepoProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(playlist.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            onPressed: () async {
              final items = await repo.queueItems(playlist.id).first;
              final buffer = StringBuffer('#K歌歌单\n');
              for (final row in items) {
                buffer.writeln('${row.song.title} - ${row.song.artist}');
              }
              Share.share(buffer.toString());
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () => repo.clearQueue(playlist.id),
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
                  onPressed: () => repo.removeQueueItem(entry.item.id),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
