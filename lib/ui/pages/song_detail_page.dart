import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../repository/song_repository.dart';
import '../../repository/tag_repository.dart';
import '../../state/providers.dart';
import '../widgets/ios_components.dart';

class SongDetailPage extends ConsumerStatefulWidget {
  const SongDetailPage({super.key, required this.song});

  final Song song;

  @override
  ConsumerState<SongDetailPage> createState() => _SongDetailPageState();
}

class _SongDetailPageState extends ConsumerState<SongDetailPage> {
  late Song _song;

  @override
  void initState() {
    super.initState();
    _song = widget.song;
  }

  @override
  Widget build(BuildContext context) {
    final tagRepo = ref.watch(tagRepoProvider);
    return Scaffold(
      backgroundColor: AppColors.groupedBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      '歌曲详情',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  IosGroupedSection(
                    header: '信息',
                    children: [
                      _CopyRow(label: '歌名', value: _song.title),
                      _CopyRow(label: '歌手', value: _song.artist),
                    ],
                  ),
                  StreamBuilder<List<Tag>>(
                    stream: tagRepo.watchTagsForSong(_song.id),
                    builder: (context, snapshot) {
                      final tags = snapshot.data ?? [];
                      return IosGroupedSection(
                        header: '标签',
                        children: [
                          if (tags.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('暂无标签', style: TextStyle(color: AppColors.secondaryLabel)),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: tags
                                    .map(
                                      (tag) => InputChip(
                                        label: Text(tag.name),
                                        onDeleted: () => tagRepo.detachSongs(tag.id, [_song.id]),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          ListTile(
                            leading: const Icon(Icons.add, color: AppColors.systemBlue),
                            title: const Text('加标签', style: TextStyle(color: AppColors.systemBlue)),
                            onTap: () => _addTag(context, tagRepo),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: IosPrimaryButton(
                label: '编辑歌曲',
                icon: Icons.edit_outlined,
                onPressed: () => _editSong(context, ref.read(songRepoProvider)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copy(String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已复制$label')));
    }
  }

  Future<void> _addTag(BuildContext context, TagRepository tagRepo) async {
    final tags = await tagRepo.watchAll().first;
    if (tags.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('暂无标签可选')));
      }
      return;
    }
    int? selectedId;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择标签'),
        content: DropdownButtonFormField<int>(
          items: tags.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))).toList(),
          onChanged: (v) => selectedId = v,
        ),
        actionsPadding: EdgeInsets.zero,
        actions: [
          IosDialogActions(
            cancelLabel: '取消',
            confirmLabel: '添加',
            onCancel: () => Navigator.pop(context),
            onConfirm: () {
              if (selectedId != null) tagRepo.attachSongs(selectedId!, [_song.id]);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _editSong(BuildContext context, SongRepository repo) async {
    final titleController = TextEditingController(text: _song.title);
    final artistController = TextEditingController(text: _song.artist);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑歌曲'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleController, decoration: const InputDecoration(labelText: '歌名')),
            const SizedBox(height: 12),
            TextField(controller: artistController, decoration: const InputDecoration(labelText: '歌手')),
          ],
        ),
        actionsPadding: EdgeInsets.zero,
        actions: [
          IosDialogActions(
            cancelLabel: '取消',
            confirmLabel: '保存',
            onCancel: () => Navigator.pop(context),
            onConfirm: () async {
              await repo.updateSong(_song.id, titleController.text, artistController.text);
              if (mounted) {
                setState(() {
                  _song = _song.copyWith(
                    title: titleController.text.trim(),
                    artist: artistController.text.trim(),
                  );
                });
              }
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _CopyRow({required String label, required String value}) {
    return ListTile(
      title: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.secondaryLabel)),
      subtitle: Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      trailing: IconButton(
        icon: const Icon(Icons.copy, size: 20, color: AppColors.systemBlue),
        onPressed: () => _copy(label, value),
      ),
    );
  }
}
