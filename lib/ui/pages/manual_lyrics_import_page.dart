import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../state/providers.dart';
import 'ai_settings_page.dart';
import 'lyrics_edit_page.dart';
import 'lyrics_processing_page.dart';

class ManualLyricsImportPage extends ConsumerStatefulWidget {
  const ManualLyricsImportPage({super.key, required this.song});

  final Song song;

  @override
  ConsumerState<ManualLyricsImportPage> createState() =>
      _ManualLyricsImportPageState();
}

class _ManualLyricsImportPageState
    extends ConsumerState<ManualLyricsImportPage> {
  final _controller = TextEditingController();

  Future<void> _useAi() async {
    if (_controller.text.trim().isEmpty) {
      _showMessage('请先粘贴原始歌词');
      return;
    }
    final repository = ref.read(aiConfigRepositoryProvider);
    final config = await repository.loadConfig();
    final key = await repository.readApiKey();
    if (!mounted) return;
    if (!config.enabled || key == null || key.isEmpty) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(builder: (_) => const AiSettingsPage()),
      );
      return;
    }
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => LyricsProcessingPage(
          song: widget.song,
          rawLyrics: _controller.text,
          sourceName: '手动粘贴',
        ),
      ),
    );
    if (saved == true && mounted) Navigator.pop(context, true);
  }

  Future<void> _withoutAi() async {
    if (_controller.text.trim().isEmpty) {
      _showMessage('请先粘贴原始歌词');
      return;
    }
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => LyricsEditPage(
          songId: widget.song.id,
          songTitle: widget.song.title,
          repository: ref.read(lyricsRepoProvider),
          initialJapanese: _controller.text,
        ),
      ),
    );
    if (saved == true && mounted) Navigator.pop(context, true);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('手动添加歌词')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Text(
            '${widget.song.title} · ${widget.song.artist}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            minLines: 14,
            maxLines: null,
            decoration: const InputDecoration(
              labelText: '原始歌词',
              hintText: '在这里粘贴完整歌词，空行和重复副歌会保留',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _useAi,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('AI 整理'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: _withoutAi,
            child: const Text('不使用 AI，直接编辑'),
          ),
        ],
      ),
    );
  }
}
