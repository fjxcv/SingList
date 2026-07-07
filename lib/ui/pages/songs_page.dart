import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../repository/playlist_repository.dart';
import '../../repository/song_repository.dart';
import '../../repository/tag_repository.dart';
import '../../service/normalize.dart';
import '../../state/providers.dart';
import '../widgets/import_flow.dart';
import '../widgets/ios_components.dart';
import 'settings_page.dart';
import 'song_detail_page.dart';

class SongsPage extends ConsumerStatefulWidget {
  const SongsPage({super.key});

  @override
  ConsumerState<SongsPage> createState() => _SongsPageState();
}

class _SongsPageState extends ConsumerState<SongsPage> {
  String keyword = '';
  int? selectedTagId;
  final selectedIds = <int>{};
  final selectionOrder = <int>[];
  bool batchMode = false;
  Set<int>? _tagSongIds;

  @override
  Widget build(BuildContext context) {
    final songsAsync = ref.watch(songsProvider);
    final tagsAsync = ref.watch(tagsWithCountProvider);
    final repo = ref.watch(songRepoProvider);
    final totalCount = songsAsync.maybeWhen(data: (songs) => songs.length, orElse: () => null);
    final titleText = batchMode
        ? '已选 ${selectedIds.length}'
        : '曲库${totalCount == null ? '' : ' ($totalCount)'}';

    return Scaffold(
      backgroundColor: AppColors.groupedBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            IosLargeTitleHeader(
              title: titleText,
              actions: batchMode
                  ? [
                      IosIconAction(
                        icon: Icons.close,
                        tooltip: '取消选择',
                        onPressed: _exitBatchMode,
                      ),
                    ]
                  : [
                      IosIconAction(
                        icon: Icons.settings_outlined,
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SettingsPage()),
                        ),
                      ),
                      IosIconAction(
                        icon: Icons.add,
                        onPressed: () => _showAddDialog(context, repo),
                      ),
                      IosIconAction(
                        icon: Icons.upload_file,
                        onPressed: () => showImportFlow(context, ref),
                      ),
                    ],
            ),
            IosSearchField(
              hintText: '歌名/歌手搜索',
              onChanged: (v) => setState(() => keyword = v),
            ),
            tagsAsync.when(
              data: (tags) => _buildTagFilters(tags),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: songsAsync.when(
                data: (songs) => _buildSongList(context, repo, songs),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('加载失败: $e')),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: batchMode ? _buildBatchBar(context, repo) : null,
    );
  }

  Widget _buildTagFilters(List<TagWithCount> tags) {
    if (tags.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: const Text('全部'),
              selected: selectedTagId == null,
              onSelected: (_) => setState(() {
                selectedTagId = null;
                _tagSongIds = null;
              }),
            ),
          ),
          for (final item in tags)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text('${item.tag.name} (${item.songCount})'),
                selected: selectedTagId == item.tag.id,
                onSelected: (_) => _selectTag(item.tag.id),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _selectTag(int tagId) async {
    final ids = await ref.read(tagRepoProvider).songIdsByTag(tagId);
    setState(() {
      selectedTagId = tagId;
      _tagSongIds = ids;
    });
  }

  Widget _buildSongList(BuildContext context, SongRepository repo, List<Song> songs) {
    var list = songs.where((s) {
      if (!matchesSongKeyword(
        titleNorm: s.titleNorm,
        artistNorm: s.artistNorm,
        keyword: keyword,
      )) {
        return false;
      }
      if (_tagSongIds != null && !_tagSongIds!.contains(s.id)) return false;
      return true;
    }).toList();

    if (list.isEmpty) {
      return const Center(child: Text('暂无歌曲，点击右上角添加'));
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        IosGroupedSection(
          children: list.map((song) {
            final checked = selectedIds.contains(song.id);
            return IosListRow(
              title: song.title,
              subtitle: song.artist,
              selected: checked,
              trailing: batchMode
                  ? Checkbox(value: checked, onChanged: (_) => _toggleSelection(song.id))
                  : null,
              onTap: () => batchMode
                  ? _toggleSelection(song.id)
                  : Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => SongDetailPage(song: song)),
                    ),
              onLongPress: () =>
                  batchMode ? _toggleSelection(song.id) : _showSongActions(context, repo, song),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildBatchBar(BuildContext context, SongRepository repo) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.separator, width: 0.5)),
        ),
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.tonal(
              onPressed: selectedIds.isEmpty ? null : () => _addTags(context, selectionOrder.toList()),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 32), padding: const EdgeInsets.symmetric(horizontal: 12)),
              child: const Text('加标签'),
            ),
            FilledButton.tonal(
              onPressed: selectedIds.isEmpty ? null : () => _addToPlaylist(context, selectionOrder.toList()),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 32), padding: const EdgeInsets.symmetric(horizontal: 12)),
              child: const Text('加入歌单'),
            ),
            FilledButton.tonal(
              onPressed: selectedIds.isEmpty ? null : () => _confirmBatchDelete(context, repo),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 32), padding: const EdgeInsets.symmetric(horizontal: 12)),
              child: const Text('删除'),
            ),
            Text('${selectedIds.length} 已选'),
            TextButton(onPressed: _exitBatchMode, child: const Text('取消')),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddDialog(BuildContext context, SongRepository repo) async {
    final titleController = TextEditingController();
    final artistController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加歌曲'),
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
            confirmLabel: '添加',
            onCancel: () => Navigator.pop(context),
            onConfirm: () async {
              final result = await repo.addSong(titleController.text, artistController.text);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(result == SongUpsertResult.created ? '添加成功' : '歌曲已存在')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _toggleSelection(int songId) {
    setState(() {
      if (selectedIds.contains(songId)) {
        selectedIds.remove(songId);
        selectionOrder.remove(songId);
      } else {
        selectedIds.add(songId);
        selectionOrder.add(songId);
      }
    });
  }

  void _exitBatchMode() {
    setState(() {
      batchMode = false;
      selectedIds.clear();
      selectionOrder.clear();
    });
  }

  Future<void> _editDialog(BuildContext context, SongRepository repo, Song song) async {
    final titleController = TextEditingController(text: song.title);
    final artistController = TextEditingController(text: song.artist);
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
            onConfirm: () {
              repo.updateSong(song.id, titleController.text, artistController.text);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _addTags(BuildContext context, List<int> songIds) async {
    final tagRepo = ref.read(tagRepoProvider);
    final tagsAsync = await tagRepo.watchAll().first;
    if (tagsAsync.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('暂无标签可选')));
      }
      return;
    }
    int? selectedTagId;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择标签'),
        content: DropdownButtonFormField<int>(
          items: tagsAsync.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))).toList(),
          onChanged: (v) => selectedTagId = v,
        ),
        actionsPadding: EdgeInsets.zero,
        actions: [
          IosDialogActions(
            cancelLabel: '取消',
            confirmLabel: '确定',
            onCancel: () => Navigator.pop(context),
            onConfirm: () {
              if (selectedTagId != null) tagRepo.attachSongs(selectedTagId!, songIds);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _addToPlaylist(BuildContext context, List<int> songIds) async {
    final playlistRepo = ref.read(playlistRepoProvider);
    final normalPlaylists = await playlistRepo.watchByType(PlaylistType.normal).first;
    final queuePlaylists = await playlistRepo.watchByType(PlaylistType.kQueue).first;
    if (normalPlaylists.isEmpty && queuePlaylists.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('暂无可加入的歌单')));
      }
      return;
    }
    int? selectedPlaylistId;
    PlaylistType selectedType = PlaylistType.normal;
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final playlists = selectedType == PlaylistType.normal ? normalPlaylists : queuePlaylists;
          return AlertDialog(
            title: const Text('加入歌单'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<PlaylistType>(
                  initialValue: selectedType,
                  items: const [
                    DropdownMenuItem(value: PlaylistType.normal, child: Text('普通歌单')),
                    DropdownMenuItem(value: PlaylistType.kQueue, child: Text('KQueue 队列')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setDialogState(() {
                      selectedType = v;
                      selectedPlaylistId = null;
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  items: playlists.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                  onChanged: (v) => selectedPlaylistId = v,
                ),
              ],
            ),
            actionsPadding: EdgeInsets.zero,
            actions: [
              IosDialogActions(
                cancelLabel: '取消',
                confirmLabel: '加入',
                onCancel: () => Navigator.pop(context),
                onConfirm: () async {
                  if (selectedPlaylistId != null) {
                    await _handleAddToPlaylist(playlistRepo, selectedPlaylistId!, selectedType, songIds);
                  }
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _handleAddToPlaylist(
    PlaylistRepository repo,
    int playlistId,
    PlaylistType type,
    List<int> songIds,
  ) async {
    if (type == PlaylistType.normal) {
      await repo.addSongsToPlaylist(playlistId, songIds);
      return;
    }
    final existing = await repo.queueItems(playlistId).first;
    var position = existing.length;
    for (final songId in songIds) {
      await repo.enqueue(playlistId, songId, position++);
    }
  }

  Future<void> _showSongActions(BuildContext context, SongRepository repo, Song song) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('编辑歌曲'),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('删除歌曲'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
            ListTile(
              leading: const Icon(Icons.label_outline),
              title: const Text('加标签'),
              onTap: () => Navigator.pop(context, 'tag'),
            ),
            ListTile(
              leading: const Icon(Icons.queue_music),
              title: const Text('加入歌单'),
              onTap: () => Navigator.pop(context, 'playlist'),
            ),
            ListTile(
              leading: const Icon(Icons.select_all),
              title: const Text('批量操作'),
              onTap: () => Navigator.pop(context, 'batch'),
            ),
          ],
        ),
      ),
    );
    if (action == null) return;
    switch (action) {
      case 'edit':
        await _editDialog(context, repo, song);
      case 'delete':
        await _confirmDelete(context, repo, [song.id]);
      case 'tag':
        await _addTags(context, [song.id]);
      case 'playlist':
        await _addToPlaylist(context, [song.id]);
      case 'batch':
        setState(() {
          batchMode = true;
          selectedIds..clear()..add(song.id);
          selectionOrder..clear()..add(song.id);
        });
    }
  }

  Future<void> _confirmBatchDelete(BuildContext context, SongRepository repo) async {
    await _confirmDelete(context, repo, selectionOrder.toList(), showCountDialog: true);
  }

  Future<void> _confirmDelete(
    BuildContext context,
    SongRepository repo,
    List<int> songIds, {
    bool showCountDialog = false,
  }) async {
    final confirmed = await showIosConfirmDialog(
      context,
      title: '确认删除',
      message: '确定要删除选中的歌曲吗？',
    );
    if (confirmed != true) return;
    var successCount = 0;
    for (final id in songIds) {
      await repo.deleteSong(id);
      successCount++;
    }
    if (showCountDialog && context.mounted) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('删除完成'),
          content: Text('成功删除 $successCount 首歌曲'),
          actionsPadding: EdgeInsets.zero,
          actions: [IosDialogDismiss(onPressed: () => Navigator.pop(context))],
        ),
      );
      _exitBatchMode();
    }
  }
}
