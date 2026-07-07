import 'dart:io';

void main() {
  File('lib/ui/pages/queue_page.dart').writeAsStringSync(_content);
  print('queue_page.dart written');
}

const _content = r'''
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/db/app_database.dart';
import '../../repository/playlist_repository.dart';
import '../../repository/song_repository.dart';
import '../../service/normalize.dart';
import '../../state/providers.dart';
import '../widgets/collapsible_selected_chips.dart';
import '../widgets/ios_components.dart';

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
      backgroundColor: AppColors.groupedBackground,
      appBar: AppBar(
        title: Text(selectionMode ? '\u5df2\u9009 ${selectedItemIds.length}' : widget.playlist.name),
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
              tooltip: '\u53d6\u6d88\u9009\u62e9',
              onPressed: _exitSelectionMode,
            ),
        ],
      ),
      body: StreamBuilder<List<QueueItemWithSong>>(
        stream: repo.queueItems(widget.playlist.id),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final items = snapshot.data!;
          if (items.isEmpty) {
            return const Center(child: Text('\u961f\u5217\u4e3a\u7a7a'));
          }
          return ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
                    decoration: BoxDecoration(
                      color: AppColors.destructive,
                      borderRadius: BorderRadius.circular(AppRadii.small),
                    ),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: const Text(
                      '\u5220\u9664',
                      style: TextStyle(color: AppColors.surface, fontWeight: FontWeight.w600),
                    ),
                  ),
                  confirmDismiss: (_) => _confirmRemoveItem(context),
                  onDismissed: (_) async {
                    await repo.removeQueueItem(entry.item.id);
                  },
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: IosIndexBadge(index: index + 1),
                    title: Text(
                      entry.song.title,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      entry.song.artist,
                      style: const TextStyle(fontSize: 13, color: AppColors.secondaryLabel),
                    ),
                    tileColor: isSelected
                        ? AppColors.lightBlueFill.withValues(alpha: 0.35)
                        : AppColors.surface,
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
                            child: const Icon(Icons.drag_handle, color: AppColors.secondaryLabel),
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
                  color: Theme.of(context).colorScheme.surfaceVariant.withValues(alpha: 0.4),
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
                      child: const Text('\u79fb\u52a8...'),
                    ),
                    FilledButton.tonal(
                      onPressed: selectedItemIds.isEmpty
                          ? null
                          : () => _confirmDeleteSelected(context, repo),
                      child: const Text('\u5220\u9664\u6240\u9009'),
                    ),
                    Text('${selectedItemIds.length} \u5df2\u9009'),
                    TextButton(
                      onPressed: _exitSelectionMode,
                      child: const Text('\u53d6\u6d88'),
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
                  .where((s) => matchesSongKeyword(
                        titleNorm: s.titleNorm,
                        artistNorm: s.artistNorm,
                        keyword: keyword,
                      ))
                  .toList();
          final selectedSongs = selectedOrder
              .map((id) => allSongs.firstWhere((song) => song.id == id))
              .toList();
          final maxListHeight = MediaQuery.of(context).size.height * 0.45;
          return AlertDialog(
            title: const Text('\u6dfb\u52a0\u6b4c\u66f2\u5230\u961f\u5217'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: '\u641c\u7d22\u6b4c\u66f2',
                    ),
                    onChanged: (value) => setState(() => keyword = value),
                  ),
                  const SizedBox(height: 12),
                  if (selectedSongs.isNotEmpty)
                    CollapsibleSelectedChips(
                      header: const Text('\u5df2\u9009\u987a\u5e8f'),
                      countLabelBuilder: (count) => '\u5df2\u9009 $count \u9996',
                      chips: selectedSongs
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
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.maxFinite,
                    height: maxListHeight,
                    child: filtered.isEmpty
                        ? const Center(child: Text('\u6682\u65e0\u5339\u914d\u6b4c\u66f2'))
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
                                    ? Theme.of(context).colorScheme.surfaceVariant.withValues(alpha: 0.3)
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
            actionsPadding: EdgeInsets.zero,
            actions: [
              IosDialogActions(
                cancelLabel: '\u53d6\u6d88',
                confirmLabel: '\u6dfb\u52a0',
                confirmEnabled: selectedOrder.isNotEmpty,
                onCancel: () => Navigator.pop(dialogContext),
                onConfirm: () async {
                  final existing = await repo.queueItems(widget.playlist.id).first;
                  var position = existing.length;
                  for (final songId in selectedOrder) {
                    await repo.enqueue(widget.playlist.id, songId, position);
                    position += 1;
                  }
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                },
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
        const SnackBar(content: Text('\u8bf7\u5148\u9009\u62e9\u6b4c\u66f2')),
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
      insertIndex = target.position! - 1;
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
        const SnackBar(content: Text('\u8bf7\u5148\u9009\u62e9\u6b4c\u66f2')),
      );
      return;
    }
    final confirmed = await showIosConfirmDialog(
      context,
      title: '\u786e\u8ba4\u5220\u9664',
      message: '\u786e\u5b9a\u8981\u5220\u9664\u9009\u4e2d\u7684 ${selectedItemIds.length} \u9996\u6b4c\u66f2\u5417\uff1f',
    );
    if (confirmed != true) return;
    for (final id in selectedItemIds) {
      await repo.removeQueueItem(id);
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('\u5220\u9664\u6210\u529f ${selectedItemIds.length} \u9996')),
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
          title: const Text('\u79fb\u52a8...'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '\u76ee\u6807\u4f4d\u7f6e (1..N+1)'),
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
                decoration: const InputDecoration(labelText: '\u6216\u9009\u62e9\u6b4c\u66f2'),
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
                  const Text('\u63d2\u5165\u5230\u8be5\u6b4c\u66f2\u4e0b\u65b9'),
                ],
              ),
              if (errorText != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(errorText!, style: const TextStyle(color: Colors.red)),
                ),
            ],
          ),
          actionsPadding: EdgeInsets.zero,
          actions: [
            IosDialogActions(
              cancelLabel: '\u53d6\u6d88',
              confirmLabel: '\u786e\u8ba4',
              onCancel: () => Navigator.pop(dialogContext),
              onConfirm: () {
                if (anchorItemId == null && position == null) {
                  setState(() => errorText = '\u8bf7\u8f93\u5165\u76ee\u6807\u4f4d\u7f6e\u6216\u9009\u62e9\u6b4c\u66f2');
                  return;
                }
                final maxPosition = items.length + 1;
                if (position != null && (position! < 1 || position! > maxPosition)) {
                  setState(() => errorText = '\u4f4d\u7f6e\u9700\u5728 1 \u5230 $maxPosition \u4e4b\u95f4');
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
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmRemoveItem(BuildContext context) async {
    final confirmed = await showIosConfirmDialog(
      context,
      title: '\u786e\u8ba4\u5220\u9664',
      message: '\u786e\u5b9a\u8981\u5220\u9664\u6b64\u6b4c\u66f2\u5417\uff1f',
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
''';
