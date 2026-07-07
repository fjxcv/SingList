import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../service/import_parser.dart';
import '../../service/import_service.dart';
import '../../service/settings_service.dart';
import '../../state/providers.dart';
import '../pages/queue_page.dart';
import 'import_preview_dialog.dart';
import 'ios_components.dart';

Future<void> showImportFlow(
  BuildContext context,
  WidgetRef ref, {
  ImportTarget defaultTarget = ImportTarget.library,
  int? playlistId,
  String? playlistName,
}) async {
  final source = await showModalBottomSheet<_ImportSource>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      decoration: const BoxDecoration(
        color: AppColors.groupedBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.large)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const IosSheetHandle(),
            ListTile(
              leading: const Icon(Icons.content_paste),
              title: const Text('粘贴文本'),
              onTap: () => Navigator.pop(context, _ImportSource.paste),
            ),
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: const Text('选择文件 (txt / csv)'),
              onTap: () => Navigator.pop(context, _ImportSource.file),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
  if (source == null || !context.mounted) return;

  String? raw;
  String? filename;
  if (source == _ImportSource.paste) {
    raw = await _showPasteDialog(context);
  } else {
    final picked = await _pickFile();
    if (picked == null) return;
    raw = picked.$1;
    filename = picked.$2;
  }
  if (raw == null || raw.trim().isEmpty || !context.mounted) return;

  final parseResult = parseImportContent(raw, filename: filename);
  if (parseResult.songs.isEmpty && parseResult.errorLines.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('没有可导入的内容')));
    }
    return;
  }

  if (!context.mounted) return;
  final result = await showDialog<ImportResult>(
    context: context,
    builder: (context) => ImportPreviewDialog(
      parseResult: parseResult,
      defaultTarget: defaultTarget,
      initialPlaylistId: playlistId,
      initialPlaylistName: playlistName,
    ),
  );
  if (result == null || !context.mounted) return;

  _showImportSnackBar(context, result);

  if (result.queuePlaylistId != null) {
    final playlist = await ref.read(playlistRepoProvider).findById(result.queuePlaylistId!);
    if (playlist != null && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => QueuePage(playlist: playlist)),
      );
    }
  }
}

enum _ImportSource { paste, file }

Future<String?> _showPasteDialog(BuildContext context) async {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('粘贴内容'),
      content: TextField(
        controller: controller,
        maxLines: 12,
        decoration: const InputDecoration(
          hintText: '每行一首，支持：歌名 - 歌手',
        ),
      ),
      actionsPadding: EdgeInsets.zero,
      actions: [
        IosDialogActions(
          cancelLabel: '取消',
          confirmLabel: '下一步',
          onCancel: () => Navigator.pop(context),
          onConfirm: () => Navigator.pop(context, controller.text),
        ),
      ],
    ),
  );
}

Future<(String, String)?> _pickFile() async {
  try {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return null;
    return (String.fromCharCodes(bytes), file.name);
  } catch (_) {
    return null;
  }
}

void _showImportSnackBar(BuildContext context, ImportResult result) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        '新增 ${result.created} 首，跳过重复 ${result.existed} 首，解析失败 ${result.errorCount} 行',
      ),
    ),
  );
}
