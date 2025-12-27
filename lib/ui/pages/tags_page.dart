import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../repository/tag_repository.dart';
import '../../state/providers.dart';
import 'songs_by_tag_page.dart';

class TagsPage extends ConsumerWidget {
  const TagsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            return ListTile(
              title: Text(tag.name),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => SongsByTagPage(tag: tag)),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _showTagDialog(context, repo, tag: tag),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => repo.delete(tag.id),
                  )
                ],
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
      ),
    );
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
