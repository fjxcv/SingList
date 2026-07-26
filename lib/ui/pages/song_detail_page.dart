import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../lyrics/lyrics_repository.dart';
import '../../repository/song_repository.dart';
import '../../repository/tag_repository.dart';
import '../../state/providers.dart';
import 'lyrics_edit_page.dart';
import 'lyrics_view_page.dart';
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
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
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
                      _copyRow(label: '歌名', value: _song.title),
                      _copyRow(label: '歌手', value: _song.artist),
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
                              child: Text('暂无标签',
                                  style: TextStyle(
                                      color: AppColors.secondaryLabel)),
                            )
                          else
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 12, 16, 12),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: tags
                                    .map(
                                      (tag) => InputChip(
                                        label: Text(tag.name),
                                        onDeleted: () => tagRepo
                                            .detachSongs(tag.id, [_song.id]),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          ListTile(
                            leading: const Icon(Icons.add,
                                color: AppColors.systemBlue),
                            title: const Text('加标签',
                                style: TextStyle(color: AppColors.systemBlue)),
                            onTap: () => _addTag(context, tagRepo),
                          ),
                        ],
                      );
                    },
                  ),
                  StreamBuilder<SongLyric?>(
                    stream:
                        ref.watch(lyricsRepoProvider).watchForSong(_song.id),
                    builder: (context, snapshot) {
                      return _buildLyricsSection(
                        context,
                        snapshot.data,
                        ref.watch(lyricsRepoProvider),
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

  Widget _buildLyricsSection(
    BuildContext context,
    SongLyric? lyrics,
    LyricsRepository repository,
  ) {
    return IosGroupedSection(
      header: '注音歌词',
      children: [
        if (lyrics == null)
          ListTile(
            leading: const Icon(
              Icons.lyrics_outlined,
              color: AppColors.systemBlue,
            ),
            title: const Text(
              '添加歌词',
              style: TextStyle(color: AppColors.systemBlue),
            ),
            subtitle: const Text('添加日文注音歌词和中文翻译'),
            onTap: () => _editLyrics(context, repository),
          )
        else ...[
          ListTile(
            leading: const Icon(Icons.lyrics_outlined),
            title: const Text('查看注音歌词'),
            subtitle: Text(
              lyrics.japaneseText.split('\n').first,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LyricsViewPage(
                  song: _song,
                  initialLyrics: lyrics,
                  repository: repository,
                ),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('编辑歌词'),
            onTap: () => _editLyrics(context, repository, lyrics: lyrics),
          ),
          ListTile(
            leading: const Icon(
              Icons.delete_outline,
              color: AppColors.destructive,
            ),
            title: const Text(
              '删除歌词',
              style: TextStyle(color: AppColors.destructive),
            ),
            onTap: () => _deleteLyrics(context, repository),
          ),
        ],
      ],
    );
  }

  Future<void> _editLyrics(
    BuildContext context,
    LyricsRepository repository, {
    SongLyric? lyrics,
  }) {
    return Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => LyricsEditPage(
          songId: _song.id,
          songTitle: _song.title,
          repository: repository,
          initialJapanese: lyrics?.japaneseText ?? '',
          initialTranslation: lyrics?.chineseTranslation ?? '',
        ),
      ),
    );
  }

  Future<void> _deleteLyrics(
    BuildContext context,
    LyricsRepository repository,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除歌词？'),
        content: const Text('日文注音歌词和中文翻译都会被删除，此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await repository.deleteForSong(_song.id);
      if (mounted) {
        ScaffoldMessenger.of(this.context).showSnackBar(
          const SnackBar(content: Text('歌词已删除')),
        );
      }
    }
  }

  Future<void> _copy(String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('已复制$label')));
    }
  }

  Future<void> _addTag(BuildContext context, TagRepository tagRepo) async {
    final tags = await tagRepo.watchAll().first;
    if (!context.mounted) return;
    if (tags.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('暂无标签可选')));
      return;
    }
    int? selectedId;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择标签'),
        content: DropdownButtonFormField<int>(
          items: tags
              .map((t) => DropdownMenuItem(value: t.id, child: Text(t.name)))
              .toList(),
          onChanged: (v) => selectedId = v,
        ),
        actionsPadding: EdgeInsets.zero,
        actions: [
          IosDialogActions(
            cancelLabel: '取消',
            confirmLabel: '添加',
            onCancel: () => Navigator.pop(context),
            onConfirm: () {
              if (selectedId != null) {
                tagRepo.attachSongs(selectedId!, [_song.id]);
              }
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
            TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: '歌名')),
            const SizedBox(height: 12),
            TextField(
                controller: artistController,
                decoration: const InputDecoration(labelText: '歌手')),
          ],
        ),
        actionsPadding: EdgeInsets.zero,
        actions: [
          IosDialogActions(
            cancelLabel: '取消',
            confirmLabel: '保存',
            onCancel: () => Navigator.pop(context),
            onConfirm: () async {
              await repo.updateSong(
                  _song.id, titleController.text, artistController.text);
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

  Widget _copyRow({required String label, required String value}) {
    return ListTile(
      title: Text(label,
          style:
              const TextStyle(fontSize: 13, color: AppColors.secondaryLabel)),
      subtitle: Text(value,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      trailing: IconButton(
        icon: const Icon(Icons.copy, size: 20, color: AppColors.systemBlue),
        onPressed: () => _copy(label, value),
      ),
    );
  }
}
