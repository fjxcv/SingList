import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../repository/tag_repository.dart';
import '../../state/providers.dart';
import '../widgets/ios_components.dart';
import 'songs_by_tag_page.dart';

class TagsPage extends ConsumerWidget {
  const TagsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(tagsWithCountProvider);
    final repo = ref.watch(tagRepoProvider);
    return Scaffold(
      backgroundColor: AppColors.groupedBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            IosLargeTitleHeader(
              title: '标签',
              actions: [
                IosIconAction(
                  icon: Icons.add,
                  onPressed: () => _showTagDialog(context, repo),
                ),
              ],
            ),
            Expanded(
              child: tagsAsync.when(
                data: (tags) {
                  if (tags.isEmpty) {
                    return const Center(child: Text('暂无标签'));
                  }
                  return ListView(
                    padding: const EdgeInsets.only(bottom: 16),
                    children: [
                      IosGroupedSection(
                        children: tags
                            .map(
                              (item) => IosListRow(
                                title: item.tag.name,
                                subtitle: '${item.songCount} 首歌曲',
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => SongsByTagPage(tag: item.tag),
                                  ),
                                ),
                                onLongPress: () => _showTagActions(context, repo, item.tag),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('加载失败: $e')),
              ),
            ),
          ],
        ),
      ),
    );
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
          ],
        ),
      ),
    );
    if (action == null) return;
    if (action == 'edit') {
      await _showTagDialog(context, repo, tag: tag);
    } else if (action == 'delete') {
      final confirmed = await showIosConfirmDialog(
        context,
        title: '删除标签',
        message: '确认删除标签「${tag.name}」吗？',
        confirmLabel: '删除',
      );
      if (confirmed == true) {
        try {
          await repo.deleteTag(tag.id);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
          }
        }
      }
    }
  }

  Future<void> _showTagDialog(BuildContext context, TagRepository repo, {Tag? tag}) async {
    if (tag != null && protectedTagNames.contains(tag.name)) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('无法修改'),
          content: const Text('默认标签不可修改名称。'),
          actionsPadding: EdgeInsets.zero,
          actions: [IosDialogDismiss(onPressed: () => Navigator.pop(context))],
        ),
      );
      return;
    }
    final controller = TextEditingController(text: tag?.name ?? '');
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tag == null ? '新建标签' : '修改标签'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: '名称')),
        actionsPadding: EdgeInsets.zero,
        actions: [
          IosDialogActions(
            cancelLabel: '取消',
            confirmLabel: '保存',
            onCancel: () => Navigator.pop(context),
            onConfirm: () {
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
          ),
        ],
      ),
    );
  }
}
