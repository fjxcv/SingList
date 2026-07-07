import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../service/import_parser.dart';
import '../../service/import_service.dart';
import '../../service/settings_service.dart';
import '../../state/providers.dart';
import 'ios_components.dart';

class ImportPreviewDialog extends ConsumerStatefulWidget {
  const ImportPreviewDialog({
    super.key,
    required this.parseResult,
    required this.defaultTarget,
    this.initialPlaylistId,
    this.initialPlaylistName,
  });

  final ParseResult parseResult;
  final ImportTarget defaultTarget;
  final int? initialPlaylistId;
  final String? initialPlaylistName;

  @override
  ConsumerState<ImportPreviewDialog> createState() => _ImportPreviewDialogState();
}

class _ImportPreviewDialogState extends ConsumerState<ImportPreviewDialog> {
  late ImportTarget _target;
  int? _playlistId;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _target = widget.defaultTarget;
    _playlistId = widget.initialPlaylistId;
  }

  @override
  Widget build(BuildContext context) {
    final preview = widget.parseResult.songs.take(8).toList();
    final normal = ref.watch(normalPlaylistsProvider);
    final queues = ref.watch(queuePlaylistsProvider);

    return AlertDialog(
      title: const Text('导入预览'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('共 ${widget.parseResult.songs.length} 首，失败 ${widget.parseResult.errorLines.length} 行'),
            const SizedBox(height: 8),
            DropdownButtonFormField<ImportTarget>(
              value: _target,
              decoration: const InputDecoration(labelText: '导入目标'),
              items: ImportTarget.values
                  .map((t) => DropdownMenuItem(value: t, child: Text(importTargetLabel(t))))
                  .toList(),
              onChanged: (v) => setState(() {
                _target = v ?? _target;
                _playlistId = null;
              }),
            ),
            if (_target == ImportTarget.normalPlaylist) ...[
              const SizedBox(height: 8),
              normal.when(
                data: (items) => DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: '选择歌单'),
                  items: items
                      .map((p) => DropdownMenuItem(value: p.id, child: Text(p.name)))
                      .toList(),
                  onChanged: (v) => setState(() => _playlistId = v),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('加载失败: $e'),
              ),
            ],
            if (_target == ImportTarget.kQueue) ...[
              const SizedBox(height: 8),
              queues.when(
                data: (items) => DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: '选择队列（可选）'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('新建队列')),
                    ...items.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))),
                  ],
                  onChanged: (v) => setState(() => _playlistId = v),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('加载失败: $e'),
              ),
            ],
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: preview.length,
                itemBuilder: (context, index) {
                  final song = preview[index];
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(song.title),
                    subtitle: Text(song.artist),
                  );
                },
              ),
            ),
            if (widget.parseResult.songs.length > preview.length)
              Text('... 还有 ${widget.parseResult.songs.length - preview.length} 首'),
          ],
        ),
      ),
      actionsPadding: EdgeInsets.zero,
      actions: [
        IosDialogActions(
          cancelLabel: '取消',
          confirmLabel: _loading ? '导入中' : '确认导入',
          confirmEnabled: !_loading && _canConfirm(),
          onCancel: () => Navigator.pop(context),
          onConfirm: _confirmImport,
        ),
      ],
    );
  }

  bool _canConfirm() {
    if (_target == ImportTarget.normalPlaylist && _playlistId == null) return false;
    return widget.parseResult.songs.isNotEmpty;
  }

  Future<void> _confirmImport() async {
    setState(() => _loading = true);
    final service = ref.read(importServiceProvider);
    final result = await service.executeImport(
      widget.parseResult,
      ImportOptions(
        target: _target,
        playlistId: _playlistId,
        playlistName: widget.initialPlaylistName,
      ),
    );
    await ref.read(settingsServiceProvider).saveLastImportTarget(_target);
    await ref.read(settingsServiceProvider).recordImportHistory(ImportHistoryEntry(
      timestamp: DateTime.now(),
      target: _target,
      created: result.created,
      existed: result.existed,
      errorCount: result.errorCount,
    ));
    if (mounted) Navigator.pop(context, result);
  }
}
