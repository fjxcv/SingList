import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../service/duplicate_merge_service.dart';
import '../../service/import_service.dart';
import '../../service/settings_service.dart';
import '../../state/providers.dart';
import '../widgets/ios_components.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  List<ImportHistoryEntry> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = await ref.read(settingsServiceProvider).loadImportHistoryAsync();
    if (mounted) setState(() => _history = history);
  }

  @override
  Widget build(BuildContext context) {
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
                      '设置',
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
                children: [
                  IosGroupedSection(
                    header: '备份',
                    children: [
                      ListTile(
                        title: const Text('导出备份'),
                        trailing: const Icon(Icons.ios_share, color: AppColors.systemBlue),
                        onTap: _exportBackup,
                      ),
                      ListTile(
                        title: const Text('从备份恢复'),
                        trailing: const Icon(Icons.restore, color: AppColors.systemBlue),
                        onTap: _restoreBackup,
                      ),
                    ],
                  ),
                  IosGroupedSection(
                    header: '维护',
                    children: [
                      ListTile(
                        title: const Text('合并重复歌曲'),
                        trailing: const Icon(Icons.merge_type, color: AppColors.systemBlue),
                        onTap: _showDuplicateMerge,
                      ),
                    ],
                  ),
                  if (_history.isNotEmpty)
                    IosGroupedSection(
                      header: '导入记录',
                      children: _history
                          .map(
                            (e) => ListTile(
                              title: Text('${importTargetLabel(e.target)} · +${e.created} / 重复${e.existed}'),
                              subtitle: Text(e.timestamp.toString().substring(0, 16)),
                            ),
                          )
                          .toList(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportBackup() async {
    final backup = ref.read(backupServiceProvider);
    final file = await backup.writeBackupToDocuments();
    await Share.shareXFiles([XFile(file.path)], text: 'SingList 备份');
  }

  Future<void> _restoreBackup() async {
    final confirmed = await showIosConfirmDialog(
      context,
      title: '恢复备份',
      message: '恢复将追加导入备份中的歌曲，确认继续吗？',
      confirmLabel: '恢复',
    );
    if (confirmed != true) return;
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
    if (result == null || result.files.single.path == null) return;
    await ref.read(backupServiceProvider).restoreFromFile(result.files.single.path!);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('恢复完成')));
    }
  }

  Future<void> _showDuplicateMerge() async {
    final service = ref.read(duplicateMergeServiceProvider);
    final groups = await service.findDuplicateGroups();
    if (!mounted) return;
    if (groups.isEmpty) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('合并重复歌曲'),
          content: const Text('未发现重复歌曲'),
          actionsPadding: EdgeInsets.zero,
          actions: [IosDialogDismiss(onPressed: () => Navigator.pop(context))],
        ),
      );
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DuplicateMergePage(groups: groups)),
    );
  }
}

class DuplicateMergePage extends ConsumerStatefulWidget {
  const DuplicateMergePage({super.key, required this.groups});

  final List<DuplicateGroup> groups;

  @override
  ConsumerState<DuplicateMergePage> createState() => _DuplicateMergePageState();
}

class _DuplicateMergePageState extends ConsumerState<DuplicateMergePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.groupedBackground,
      appBar: AppBar(title: const Text('合并重复歌曲')),
      body: ListView.builder(
        itemCount: widget.groups.length,
        itemBuilder: (context, index) {
          final group = widget.groups[index];
          final title = group.entries.first.song.title;
          final artist = group.entries.first.song.artist;
          return IosGroupedSection(
            header: '$title - $artist (${group.entries.length} 首)',
            children: group.entries
                .map(
                  (entry) => ListTile(
                    title: Text('ID ${entry.song.id} · ${entry.song.createdAt.toString().substring(0, 10)}'),
                    subtitle: Text('标签${entry.tagCount} · 歌单${entry.playlistCount} · 队列${entry.queueCount}'),
                    trailing: TextButton(
                      child: const Text('保留'),
                      onPressed: () => _merge(group, entry.song.id),
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }

  Future<void> _merge(DuplicateGroup group, int keepId) async {
    final confirmed = await showIosConfirmDialog(
      context,
      title: '确认合并',
      message: '将合并这组重复歌曲并删除其余条目，确认吗？',
    );
    if (confirmed != true) return;
    await ref.read(duplicateMergeServiceProvider).mergeGroup(group, keepId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('合并完成')));
      Navigator.pop(context);
    }
  }
}
