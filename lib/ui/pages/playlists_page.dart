import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../repository/playlist_repository.dart';
import '../../service/import_service.dart';
import '../../state/providers.dart';
import '../widgets/import_flow.dart';
import '../widgets/ios_components.dart';
import 'queue_page.dart';
import 'simple_playlist_page.dart';

class PlaylistsPage extends ConsumerStatefulWidget {
  const PlaylistsPage({super.key});

  @override
  ConsumerState<PlaylistsPage> createState() => _PlaylistsPageState();
}

class _PlaylistsPageState extends ConsumerState<PlaylistsPage> {
  final selectedIds = <int>{};
  bool selectionMode = false;

  @override
  Widget build(BuildContext context) {
    final normal = ref.watch(normalPlaylistsProvider);
    final queues = ref.watch(queuePlaylistsProvider);
    final repo = ref.watch(playlistRepoProvider);
    return Scaffold(
      backgroundColor: AppColors.groupedBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            IosLargeTitleHeader(
              title: selectionMode ? '已选 ${selectedIds.length}' : '歌单 / 队列',
              actions: selectionMode
                  ? [
                      IosIconAction(icon: Icons.close, tooltip: '取消选择', onPressed: _exitSelectionMode),
                    ]
                  : [
                      IosIconAction(icon: Icons.add, onPressed: () => _createDialog(context, repo)),
                      IosIconAction(
                        icon: Icons.upload_file,
                        tooltip: '导入 KQueue',
                        onPressed: () => showImportFlow(context, ref, defaultTarget: ImportTarget.kQueue),
                      ),
                    ],
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  normal.when(
                    data: (items) => IosGroupedSection(
                      header: '普通歌单',
                      children: items
                          .map(
                            (p) => _buildPlaylistTile(
                              context,
                              repo,
                              p,
                              subtitle: '歌曲不重复',
                              onOpen: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => SimplePlaylistPage(playlist: p)),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('加载失败: $e')),
                  ),
                  const SizedBox(height: 8),
                  queues.when(
                    data: (items) => IosGroupedSection(
                      header: 'KQueue 队列',
                      children: items
                          .map(
                            (p) => _buildPlaylistTile(
                              context,
                              repo,
                              p,
                              subtitle: '允许重复、可拖拽',
                              onOpen: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => QueuePage(playlist: p)),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (e, _) => Center(child: Text('加载失败: $e')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: selectionMode
          ? SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant.withValues(alpha: 0.4),
                  border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton.tonal(
                      onPressed: selectedIds.isEmpty ? null : () => _confirmBatchDelete(context, repo),
                      child: const Text('删除所选'),
                    ),
                    Text('${selectedIds.length} 已选'),
                    TextButton(onPressed: _exitSelectionMode, child: const Text('取消')),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Future<void> _createDialog(BuildContext context, PlaylistRepository repo) async {
    final nameController = TextEditingController();
    var type = PlaylistType.normal;
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('新建歌单/队列'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: '名称')),
              const SizedBox(height: 8),
              DropdownButtonFormField<PlaylistType>(
                value: type,
                onChanged: (v) => setState(() => type = v ?? PlaylistType.normal),
                items: const [
                  DropdownMenuItem(value: PlaylistType.normal, child: Text('普通歌单')),
                  DropdownMenuItem(value: PlaylistType.kQueue, child: Text('KQueue 队列')),
                ],
              ),
            ],
          ),
          actionsPadding: EdgeInsets.zero,
          actions: [
            IosDialogActions(
              cancelLabel: '取消',
              confirmLabel: '创建',
              onCancel: () => Navigator.pop(context),
              onConfirm: () {
                if (nameController.text.trim().isNotEmpty) {
                  repo.create(nameController.text.trim(), type);
                }
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPlaylistActions(BuildContext context, PlaylistRepository repo, Playlist playlist) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('编辑歌单'),
              onTap: () => Navigator.pop(context, 'rename'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('批量删除'),
              onTap: () => Navigator.pop(context, 'batch-delete'),
            ),
          ],
        ),
      ),
    );
    if (action == 'rename' && context.mounted) {
      await _renamePlaylist(context, repo, playlist);
    } else if (action == 'batch-delete') {
      _enterSelectionMode(playlist.id);
    }
  }

  Future<void> _renamePlaylist(BuildContext context, PlaylistRepository repo, Playlist playlist) async {
    final controller = TextEditingController(text: playlist.name);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑歌单'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: '名称')),
        actionsPadding: EdgeInsets.zero,
        actions: [
          IosDialogActions(
            cancelLabel: '取消',
            confirmLabel: '保存',
            onCancel: () => Navigator.pop(context),
            onConfirm: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) repo.rename(playlist.id, name);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistTile(
    BuildContext context,
    PlaylistRepository repo,
    Playlist playlist, {
    required String subtitle,
    required VoidCallback onOpen,
  }) {
    final isSelected = selectedIds.contains(playlist.id);
    return IosListRow(
      title: playlist.name,
      subtitle: subtitle,
      selected: isSelected,
      trailing: selectionMode ? Checkbox(value: isSelected, onChanged: (_) => _toggleSelection(playlist.id)) : null,
      onTap: () => selectionMode ? _toggleSelection(playlist.id) : onOpen(),
      onLongPress: () =>
          selectionMode ? _toggleSelection(playlist.id) : _showPlaylistActions(context, repo, playlist),
    );
  }

  void _toggleSelection(int playlistId) {
    setState(() {
      if (selectedIds.contains(playlistId)) {
        selectedIds.remove(playlistId);
      } else {
        selectedIds.add(playlistId);
      }
    });
  }

  void _enterSelectionMode(int playlistId) {
    setState(() {
      selectionMode = true;
      selectedIds..clear()..add(playlistId);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      selectionMode = false;
      selectedIds.clear();
    });
  }

  Future<void> _confirmBatchDelete(BuildContext context, PlaylistRepository repo) async {
    final confirmed = await showIosConfirmDialog(
      context,
      title: '确认删除',
      message: '确定要删除选中的 ${selectedIds.length} 个歌单吗？',
    );
    if (confirmed != true) return;
    for (final id in selectedIds) {
      await repo.delete(id);
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('删除成功 ${selectedIds.length} 个歌单')));
      _exitSelectionMode();
    }
  }
}
