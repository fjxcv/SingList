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
              if (selectionMode) return;
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
                        if (!selectionMode)
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
      bottomNavigationBar: selectionMode
          ? SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(context).dividerColor,
                    ),
                  ),
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton.tonal(
                      onPressed: () => _handleMoveSelected(context, repo),
                      child: const Text('移动到...'),
                    ),
                    FilledButton.tonal(
                      onPressed: selectedItemIds.isEmpty
                          ? null
                          : () => _confirmDeleteSelected(context, repo),
                      child: const Text('删除所选'),
                    ),
                    Text('${selectedItemIds.length} 已选'),
                    TextButton(
                      onPressed: _exitSelectionMode,
                      child: const Text('取消'),
                    ),
                  ],
                ),
              ),
            )
          : null,
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
          final maxListHeight = MediaQuery.of(context).size.height * 0.45;
          return AlertDialog(
            title: const Text('添加歌曲到队列'),
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
                    height: maxListHeight,
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
    final ids = items.map((e) => e.item.id).toList();
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

  Future<void> _handleMoveSelected(
    BuildContext context,
    PlaylistRepository repo,
  ) async {
    if (selectedItemIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择歌曲')),
      );
      return;
    }
    final items = await repo.queueItems(widget.playlist.id).first;
    final target = await _showMoveDialog(context, items);
    if (target == null) return;
    final ids = items.map((e) => e.item.id).toList();
    final selectedIdsInOrder = ids.where(selectedItemIds.contains).toList();
    final remaining = ids.where((id) => !selectedItemIds.contains(id)).toList();
    int insertIndex;
    if (target.anchorItemId != null) {
      final anchorIndex =
          remaining.indexWhere((id) => id == target.anchorItemId);
      if (anchorIndex == -1) return;
      insertIndex = target.insertBelow ? anchorIndex + 1 : anchorIndex;
    } else {
      insertIndex = target.position - 1;
    }
    if (insertIndex < 0) insertIndex = 0;
    if (insertIndex > remaining.length) insertIndex = remaining.length;
    remaining.insertAll(insertIndex, selectedIdsInOrder);
    await repo.reorderQueue(widget.playlist.id, remaining);
  }

  Future<void> _confirmDeleteSelected(
    BuildContext context,
    PlaylistRepository repo,
  ) async {
    if (selectedItemIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择歌曲')),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除选中的 ${selectedItemIds.length} 首歌曲吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('确认')),
        ],
      ),
    );
    if (confirmed != true) return;
    for (final id in selectedItemIds) {
      await repo.removeQueueItem(id);
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('删除成功 ${selectedItemIds.length} 首')),
    );
    _exitSelectionMode();
  }

  Future<_MoveTarget?> _showMoveDialog(
    BuildContext context,
    List<QueueItemWithSong> items,
  ) async {
    final availableAnchors = items.where((item) => !selectedItemIds.contains(item.item.id)).toList();
    int? position;
    int? anchorItemId;
    var insertBelow = false;
    String? errorText;
    return showDialog<_MoveTarget>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('移动到...'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '目标位置 (1..N+1)'),
                onChanged: (value) {
                  final parsed = int.tryParse(value.trim());
                  setState(() {
                    position = parsed;
                    errorText = null;
                  });
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: anchorItemId,
                decoration: const InputDecoration(labelText: '或选择歌曲'),
                items: availableAnchors
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry.item.id,
                        child: Text(entry.song.title),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    anchorItemId = value;
                    errorText = null;
                  });
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Checkbox(
                    value: insertBelow,
                    onChanged: anchorItemId == null
                        ? null
                        : (value) => setState(() => insertBelow = value ?? false),
                  ),
                  const Text('插到该歌曲下方'),
                ],
              ),
              if (errorText != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(errorText!, style: const TextStyle(color: Colors.red)),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                if (anchorItemId == null && position == null) {
                  setState(() => errorText = '请输入目标位置或选择歌曲');
                  return;
                }
                final maxPosition = items.length + 1;
                if (position != null && (position! < 1 || position! > maxPosition)) {
                  setState(() => errorText = '位置需在 1 到 $maxPosition 之间');
                  return;
                }
                if (anchorItemId != null) {
                  Navigator.pop(
                    dialogContext,
                    _MoveTarget(anchorItemId: anchorItemId, insertBelow: insertBelow),
                  );
                  return;
                }
                Navigator.pop(
                  dialogContext,
                  _MoveTarget(position: position ?? maxPosition),
                );
              },
              child: const Text('确认'),
            ),
          ],
        ),
      ),
    );
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

class _MoveTarget {
  _MoveTarget({this.position, this.anchorItemId, this.insertBelow = false});

  final int? position;
  final int? anchorItemId;
  final bool insertBelow;
}
