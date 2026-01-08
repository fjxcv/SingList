import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/db/app_database.dart';
import '../../repository/playlist_repository.dart';
import '../../repository/song_repository.dart';
import '../../state/providers.dart';
import '../../service/kqueue_text_service.dart';

class QueuePage extends ConsumerStatefulWidget {
  final Playlist playlist;
  const QueuePage({super.key, required this.playlist});

  @override
  ConsumerState<QueuePage> createState() => _QueuePageState();
}

class _QueuePageState extends ConsumerState<QueuePage> {
  final selectedItemIds = <int>{};
  bool selectionMode = false;

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(playlistRepoProvider);
    final textService = ref.watch(kqueueTextServiceProvider);
    final songRepo = ref.watch(songRepoProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(selectionMode ? '已选 ${selectedItemIds.length}' : widget.playlist.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.playlist_add),
            onPressed: () => _addSongsDialog(context, repo, songRepo),
          ),
          IconButton(
            icon: const Icon(Icons.ios_share),
            onPressed: () async {
              final text = await textService.exportQueueAsText(widget.playlist.id);
              Share.share(text);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () => _confirmClearQueue(context, repo),
          ),
          if (selectionMode)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: '取消选择',
              onPressed: _exitSelectionMode,
            ),
        ],
      ),
      body: StreamBuilder<List<QueueItemWithSong>>(
        stream: repo.queueItems(widget.playlist.id),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final items = snapshot.data!;
          if (items.isEmpty) return const Center(child: Text('队列为空'));
          return ReorderableListView.builder(
            itemCount: items.length,
            buildDefaultDragHandles: false,
            onReorder: (oldIndex, newIndex) async {
              await _handleReorder(repo, items, oldIndex, newIndex);
            },
            itemBuilder: (context, index) {
              final entry = items[index];
              final isSelected = selectedItemIds.contains(entry.item.id);
              return KeyedSubtree(
                key: ValueKey(entry.item.id),
                child: Dismissible(
                  key: ValueKey('dismiss-${entry.item.id}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Theme.of(context).colorScheme.error,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (_) => _confirmRemoveItem(context),
                  onDismissed: (_) async {
                    await repo.removeQueueItem(entry.item.id);
                  },
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 14,
                      child: Text('${index + 1}'),
                    ),
                    title: Text(entry.song.title),
                    subtitle: Text(entry.song.artist),
                    tileColor: isSelected
                        ? Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.35)
                        : null,
                    onTap: () {
                      if (selectionMode) {
                        _toggleSelection(entry.item.id);
                      }
                    },
                    onLongPress: () {
                      if (!selectionMode) {
                        setState(() {
                          selectionMode = true;
                        });
                      }
                      _toggleSelection(entry.item.id);
                    },
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (selectionMode)
                          Checkbox(
                            value: isSelected,
                            onChanged: (_) => _toggleSelection(entry.item.id),
                          ),
                        ReorderableDragStartListener(
                          index: index,
                          child: const Icon(Icons.drag_handle),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _addSongsDialog(
    BuildContext context,
    PlaylistRepository repo,
    SongRepository songRepo,
  ) async {
    final allSongs = await songRepo.watchAll().first;
    final selectedOrder = <int>[];
    final selectedSet = <int>{};
    String keyword = '';
    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          final filtered = keyword.isEmpty
              ? allSongs
              : allSongs
                  .where((s) => s.title.contains(keyword) || s.artist.contains(keyword))
                  .toList();
          final selectedSongs = selectedOrder
              .map((id) => allSongs.firstWhere((song) => song.id == id))
              .toList();
          return AlertDialog(
            title: const Text('添加歌曲到队列'),
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
                if (selectedSongs.isNotEmpty)
                  Container(
                    width: double.maxFinite,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('已选顺序'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: selectedSongs
                              .asMap()
                              .entries
                              .map(
                                (entry) => Chip(
                                  label: Text('${entry.key + 1}. ${entry.value.title}'),
                                  onDeleted: () {
                                    setState(() {
                                      selectedSet.remove(entry.value.id);
                                      selectedOrder.remove(entry.value.id);
                                    });
                                  },
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
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
                            final selected = selectedSet.contains(song.id);
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
                                    selectedSet.remove(song.id);
                                    selectedOrder.remove(song.id);
                                  } else {
                                    selectedSet.add(song.id);
                                    selectedOrder.add(song.id);
                                  }
                                });
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('取消')),
              FilledButton(
                onPressed: selectedOrder.isEmpty
                    ? null
                    : () async {
                        final existing = await repo.queueItems(widget.playlist.id).first;
                        var position = existing.length;
                        for (final songId in selectedOrder) {
                          await repo.enqueue(widget.playlist.id, songId, position);
                          position += 1;
                        }
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

  Future<void> _handleReorder(
    PlaylistRepository repo,
    List<QueueItemWithSong> items,
    int oldIndex,
    int newIndex,
  ) async {
    var adjustedNewIndex = newIndex;
    if (adjustedNewIndex > oldIndex) adjustedNewIndex -= 1;
    final draggedId = items[oldIndex].item.id;
    final ids = items.map((e) => e.item.id).toList();
    if (selectionMode && selectedItemIds.contains(draggedId) && selectedItemIds.length > 1) {
      final selectedIdsInOrder = ids.where(selectedItemIds.contains).toList();
      final remaining = ids.where((id) => !selectedItemIds.contains(id)).toList();
      var removalBefore = 0;
      for (var i = 0; i < ids.length; i++) {
        if (i < adjustedNewIndex && selectedItemIds.contains(ids[i])) {
          removalBefore += 1;
        }
      }
      var insertIndex = adjustedNewIndex - removalBefore;
      if (insertIndex < 0) insertIndex = 0;
      if (insertIndex > remaining.length) insertIndex = remaining.length;
      remaining.insertAll(insertIndex, selectedIdsInOrder);
      await repo.reorderQueue(widget.playlist.id, remaining);
      return;
    }
    final mutable = List.of(ids);
    final moved = mutable.removeAt(oldIndex);
    mutable.insert(adjustedNewIndex, moved);
    await repo.reorderQueue(widget.playlist.id, mutable);
  }

  void _toggleSelection(int itemId) {
    setState(() {
      if (selectedItemIds.contains(itemId)) {
        selectedItemIds.remove(itemId);
        if (selectedItemIds.isEmpty) {
          selectionMode = false;
        }
      } else {
        selectedItemIds.add(itemId);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      selectionMode = false;
      selectedItemIds.clear();
    });
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
      await repo.clearQueue(widget.playlist.id);
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

  Future<bool> _confirmRemoveItem(BuildContext context) async {
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
    return confirmed ?? false;
  }
}
