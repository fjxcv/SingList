import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../repository/tag_repository.dart';
import '../../state/providers.dart';

class TagsPage extends ConsumerStatefulWidget {
  const TagsPage({super.key});

  @override
  ConsumerState<TagsPage> createState() => _TagsPageState();
}

class _TagsPageState extends ConsumerState<TagsPage> {
  final Map<int, bool> expanded = {};

  @override
  Widget build(BuildContext context) {
    final tagsAsync = ref.watch(tagsProvider);
    final repo = ref.watch(tagRepoProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('标签'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showTagDialog(context, repo),
          )
        ],
      ),
      body: tagsAsync.when(
        data: (tags) => ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: tags.length,
          itemBuilder: (context, index) {
            final tag = tags[index];
            final isExpanded = expanded[tag.id] ?? false;
            return StreamBuilder<List<Song>>(
              stream: repo.songsByTag(tag.id),
              builder: (context, snapshot) {
                final songs = snapshot.data ?? [];
                final theme = Theme.of(context);
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      ListTile(
                        title: Row(
                          children: [
                            Expanded(child: Text(tag.name, style: theme.textTheme.bodyLarge)),
                            Text('(${songs.length})', style: theme.textTheme.bodySmall),
                          ],
                        ),
                        onTap: () => _toggleExpanded(tag.id),
                        onLongPress: () => _showTagActions(context, repo, tag),
                        trailing: IconButton(
                          icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                          onPressed: () => _toggleExpanded(tag.id),
                        ),
                      ),
                      if (isExpanded) ...[
                        Divider(height: 1, color: theme.dividerColor.withOpacity(0.6)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Column(
                            children: songs
                                .map(
                                  (song) => ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(song.title, style: theme.textTheme.bodyMedium),
                                    subtitle: Text(song.artist, style: theme.textTheme.bodySmall),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
      ),
    );
  }

  void _toggleExpanded(int tagId) {
    setState(() {
      expanded[tagId] = !(expanded[tagId] ?? false);
    });
  }

  Future<void> _showTagActions(BuildContext context, TagRepository repo, Tag tag) async {
    final isProtected = protectedTagNames.contains(tag.name);
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isProtected)
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('修改标签'),
                onTap: () => Navigator.pop(context, 'edit'),
              ),
            if (!isProtected)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('删除标签'),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
            ListTile(
              leading: const Icon(Icons.remove_circle_outline),
              title: const Text('删除歌曲'),
              onTap: () => Navigator.pop(context, 'remove'),
            ),
            ListTile(
              leading: const Icon(Icons.playlist_remove),
              title: const Text('批量删除歌曲'),
              onTap: () => Navigator.pop(context, 'batch-remove'),
            ),
          ],
        ),
      ),
    );
    if (action == 'edit') {
      await _showTagDialog(context, repo, tag: tag);
    } else if (action == 'delete') {
      await _confirmDeleteTag(context, repo, tag);
    } else if (action == 'remove') {
      await _removeSingleSong(context, repo, tag);
    } else if (action == 'batch-remove') {
      await _removeMultipleSongs(context, repo, tag);
    }
  }

  Future<void> _confirmDeleteTag(BuildContext context, TagRepository repo, Tag tag) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除标签“${tag.name}”吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('确认')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await repo.deleteTag(tag.id);
    } catch (e) {
      if (context.mounted) {
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

  Future<void> _showTagDialog(BuildContext context, TagRepository repo, {Tag? tag}) async {
    if (tag != null && protectedTagNames.contains(tag.name)) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('无法修改'),
          content: const Text('默认标签不能修改名称。'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('知道了')),
          ],
        ),
      );
      return;
    }
    final controller = TextEditingController(text: tag?.name ?? '');
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tag == null ? '新增标签' : '修改标签'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: '名称')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                if (tag == null) {
                  repo.create(name);
                } else {
                  repo.rename(tag.id, name);
                }
              }
              Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeSingleSong(BuildContext context, TagRepository repo, Tag tag) async {
    final songs = await repo.songsByTag(tag.id).first;
    if (songs.isEmpty) {
      if (context.mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('暂无歌曲'),
            content: const Text('该标签下没有可删除的歌曲。'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('知道了')),
            ],
          ),
        );
      }
      return;
    }
    String keyword = '';
    Song? selected;
    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          final filtered = keyword.isEmpty
              ? songs
              : songs
                  .where((s) => s.title.contains(keyword) || s.artist.contains(keyword))
                  .toList();
          return AlertDialog(
            title: const Text('选择要删除的歌曲'),
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
                SizedBox(
                  width: double.maxFinite,
                  height: 280,
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final song = filtered[index];
                      return ListTile(
                        title: Text(song.title),
                        subtitle: Text(song.artist),
                        onTap: () {
                          selected = song;
                          Navigator.pop(dialogContext);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('取消')),
            ],
          );
        },
      ),
    );
    if (selected == null || !context.mounted) return;
    final confirmed = await _confirmRemoveSongs(context, 1);
    if (!confirmed) return;
    await repo.detachSongs(tag.id, [selected!.id]);
  }

  Future<void> _removeMultipleSongs(BuildContext context, TagRepository repo, Tag tag) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TagBatchRemovePage(tag: tag)),
    );
  }

  Future<bool> _confirmRemoveSongs(BuildContext context, int count) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要从标签中移除 $count 首歌曲吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('确认')),
        ],
      ),
    );
    return confirmed ?? false;
  }
}

class TagBatchRemovePage extends ConsumerStatefulWidget {
  final Tag tag;
  const TagBatchRemovePage({super.key, required this.tag});

  @override
  ConsumerState<TagBatchRemovePage> createState() => _TagBatchRemovePageState();
}

class _TagBatchRemovePageState extends ConsumerState<TagBatchRemovePage> {
  final selectedIds = <int>{};
  String keyword = '';

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(tagRepoProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(selectedIds.isEmpty ? '批量删除歌曲' : '已选 ${selectedIds.length}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: '取消选择',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: StreamBuilder<List<Song>>(
        stream: repo.songsByTag(widget.tag.id),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final songs = snapshot.data!;
          if (songs.isEmpty) {
            return const Center(child: Text('该标签下没有可删除的歌曲'));
          }
          final filtered = keyword.isEmpty
              ? songs
              : songs
                  .where((s) => s.title.contains(keyword) || s.artist.contains(keyword))
                  .toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: '搜索歌曲',
                  ),
                  onChanged: (value) => setState(() => keyword = value),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final song = filtered[index];
                    final checked = selectedIds.contains(song.id);
                    return ListTile(
                      title: Text(song.title),
                      subtitle: Text(song.artist),
                      tileColor: checked
                          ? Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.35)
                          : null,
                      trailing: Checkbox(
                        value: checked,
                        onChanged: (_) => _toggleSelection(song.id),
                      ),
                      onTap: () => _toggleSelection(song.id),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
            border: Border(
              top: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.tonal(
                onPressed: selectedIds.isEmpty ? null : () => _confirmBatchRemove(context, repo),
                child: const Text('删除'),
              ),
              Text('${selectedIds.length} 已选'),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleSelection(int songId) {
    setState(() {
      if (selectedIds.contains(songId)) {
        selectedIds.remove(songId);
      } else {
        selectedIds.add(songId);
      }
    });
  }

  Future<void> _confirmBatchRemove(BuildContext context, TagRepository repo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要从标签中移除 ${selectedIds.length} 首歌曲吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('确认')),
        ],
      ),
    );
    if (confirmed != true) return;
    await repo.detachSongs(widget.tag.id, selectedIds.toList());
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已移除 ${selectedIds.length} 首歌曲')),
    );
    Navigator.pop(context);
  }
}
