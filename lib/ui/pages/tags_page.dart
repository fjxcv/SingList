import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../repository/tag_repository.dart';
import '../../state/providers.dart';
import 'songs_by_tag_page.dart';

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
          itemCount: tags.length,
          itemBuilder: (context, index) {
            final tag = tags[index];
            final isExpanded = expanded[tag.id] ?? false;
            return StreamBuilder<List<Song>>(
              stream: repo.songsByTag(tag.id),
              builder: (context, snapshot) {
                final songs = snapshot.data ?? [];
                return Column(
                  children: [
                    ListTile(
                      title: Row(
                        children: [
                          Expanded(child: Text(tag.name)),
                          Text('(${songs.length})'),
                        ],
                      ),
                      onTap: () => _toggleExpanded(tag.id),
                      onLongPress: () => _showTagActions(context, repo, tag),
                      trailing: IconButton(
                        icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                        onPressed: () => _toggleExpanded(tag.id),
                      ),
                    ),
                    if (isExpanded)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: songs
                              .map(
                                (song) => ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(song.title),
                                  subtitle: Text(song.artist),
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => SongsByTagPage(tag: tag)),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                  ],
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
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('修改标签'),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('删除标签'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (action == 'edit') {
      await _showTagDialog(context, repo, tag: tag);
    } else if (action == 'delete') {
      await _confirmDeleteTag(context, repo, tag);
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
}
