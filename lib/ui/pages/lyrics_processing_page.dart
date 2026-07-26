import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/ai_exception.dart';
import '../../ai/openai_compatible_client.dart';
import '../../data/db/app_database.dart';
import '../../lyrics/furigana_parser.dart';
import '../../lyrics/lyric_processing_result.dart';
import '../../state/providers.dart';
import '../widgets/furigana_lyrics_view.dart';
import 'ai_settings_page.dart';
import 'lyrics_edit_page.dart';

class LyricsProcessingPage extends ConsumerStatefulWidget {
  const LyricsProcessingPage({
    super.key,
    required this.song,
    required this.rawLyrics,
    required this.sourceName,
    this.sourceUrl,
    this.versionLabel,
  });

  final Song song;
  final String rawLyrics;
  final String sourceName;
  final String? sourceUrl;
  final String? versionLabel;

  @override
  ConsumerState<LyricsProcessingPage> createState() =>
      _LyricsProcessingPageState();
}

class _LyricsProcessingPageState extends ConsumerState<LyricsProcessingPage> {
  final _displayController = TextEditingController();
  final _translationController = TextEditingController();
  AiCancellationToken? _cancellationToken;
  LyricProcessingResult? _result;
  String? _error;
  String? _providerLabel;
  String? _configuredModel;
  bool _processing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _process();
  }

  Future<void> _process() async {
    _cancellationToken?.cancel();
    final token = AiCancellationToken();
    _cancellationToken = token;
    setState(() {
      _processing = true;
      _error = null;
      _result = null;
    });
    try {
      final repository = ref.read(aiConfigRepositoryProvider);
      final config = await repository.loadConfig();
      final apiKey = await repository.readApiKey() ?? '';
      if (!config.enabled || apiKey.isEmpty) {
        throw const AiException(
          AiErrorKind.invalidConfiguration,
          '请先启用 AI 服务并配置 API Key',
        );
      }
      _providerLabel = config.providerLabel;
      _configuredModel = config.model;
      final result = await ref.read(lyricAiProcessorProvider).process(
            config: config,
            apiKey: apiKey,
            title: widget.song.title,
            artist: widget.song.artist,
            rawLyrics: widget.rawLyrics,
            cancellationToken: token,
          );
      if (!mounted || token.isCancelled) return;
      _displayController.text = result.displayText;
      _translationController.text = result.translationText;
      setState(() => _result = result);
    } on AiException catch (error) {
      if (!mounted || error.kind == AiErrorKind.cancelled) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'AI 处理失败，请重试或转为手动编辑');
    } finally {
      if (mounted && !token.isCancelled) {
        setState(() => _processing = false);
      }
    }
  }

  void _cancel() {
    _cancellationToken?.cancel();
    Navigator.pop(context);
  }

  Future<void> _openSettings() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const AiSettingsPage()),
    );
    if (mounted) _process();
  }

  Future<void> _manualEdit() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => LyricsEditPage(
          songId: widget.song.id,
          songTitle: widget.song.title,
          repository: ref.read(lyricsRepoProvider),
          initialJapanese: widget.rawLyrics,
        ),
      ),
    );
    if (saved == true && mounted) Navigator.pop(context, true);
  }

  Future<void> _save() async {
    final result = _result;
    if (result == null) return;
    final error = const FuriganaParser().validate(_displayController.text);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
      return;
    }
    setState(() => _saving = true);
    await ref.read(lyricsRepoProvider).save(
          songId: widget.song.id,
          japanese: _displayController.text,
          translation: _translationController.text,
          originalText: widget.rawLyrics,
          languageCode: result.language,
          sourceName: widget.sourceName,
          sourceUrl: widget.sourceUrl,
          versionLabel: widget.versionLabel,
          aiProvider: _providerLabel,
          aiModel: result.actualModel,
          wasManuallyEdited: _displayController.text != result.displayText ||
              _translationController.text != result.translationText,
        );
    if (mounted) Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _cancellationToken?.cancel();
    _displayController.dispose();
    _translationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_result == null ? 'AI 整理歌词' : '预览歌词'),
        leading: IconButton(
          onPressed: _cancel,
          icon: const Icon(Icons.close),
        ),
      ),
      body: _processing
          ? _buildProcessing()
          : _error != null
              ? _buildError()
              : _buildPreview(),
    );
  }

  Widget _buildProcessing() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 22),
            const Text('正在整理歌词、生成注音和中文翻译……'),
            const SizedBox(height: 12),
            Text(
              '不会写入数据库，完成后需要你预览并确认保存。',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextButton(onPressed: _cancel, child: const Text('取消')),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    final needsSettings = _error!.contains('配置') || _error!.contains('启用');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 44),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            if (needsSettings)
              FilledButton(
                onPressed: _openSettings,
                child: const Text('前往 AI 设置'),
              )
            else
              FilledButton(onPressed: _process, child: const Text('重试')),
            OutlinedButton(
              onPressed: _manualEdit,
              child: const Text('转为手动编辑'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('返回并保留原始歌词'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    final result = _result!;
    final previewError =
        const FuriganaParser().validate(_displayController.text);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(label: Text('语言：${result.language}')),
            Chip(label: Text('来源：${widget.sourceName}')),
            Chip(label: Text('AI：$_providerLabel / ${result.actualModel}')),
          ],
        ),
        if (widget.versionLabel != null) ...[
          const SizedBox(height: 6),
          Text('版本：${widget.versionLabel}'),
        ],
        if (widget.sourceUrl != null) ...[
          const SizedBox(height: 6),
          SelectableText('来源链接：${widget.sourceUrl}'),
        ],
        if (result.warnings.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text('请检查不确定项：\n${result.warnings.join('\n')}'),
            ),
          ),
        ],
        const SizedBox(height: 12),
        ExpansionTile(
          title: const Text('原始歌词'),
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: SelectableText(widget.rawLyrics),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '排版预览',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                if (previewError == null)
                  FuriganaLyricsView(
                    japanese: _displayController.text,
                    translation: _translationController.text,
                    fontSize: 24,
                    showTranslation: true,
                  )
                else
                  Text(
                    '修正注音格式后可继续预览：$previewError',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _displayController,
          onChanged: (_) => setState(() {}),
          minLines: 10,
          maxLines: null,
          decoration: const InputDecoration(
            labelText: '整理后的显示/注音歌词',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _translationController,
          onChanged: (_) => setState(() {}),
          minLines: 8,
          maxLines: null,
          decoration: const InputDecoration(
            labelText: '逐行中文翻译',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _process,
          icon: const Icon(Icons.refresh),
          label: Text('重新生成（$_configuredModel）'),
        ),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? '保存中…' : '确认保存'),
        ),
        TextButton(onPressed: _cancel, child: const Text('取消，不修改原歌词')),
      ],
    );
  }
}
