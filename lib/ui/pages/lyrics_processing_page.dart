import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/ai_exception.dart';
import '../../ai/openai_compatible_client.dart';
import '../../data/db/app_database.dart';
import '../../lyrics/furigana_parser.dart';
import '../../lyrics/lyric_ai_processor.dart';
import '../../lyrics/lyric_processing_result.dart';
import '../../lyrics/lyric_search_service.dart';
import '../../lyrics/network_connectivity_service.dart';
import '../../state/providers.dart';
import '../widgets/furigana_lyrics_view.dart';
import '../widgets/line_number_text_field.dart';
import 'ai_settings_page.dart';
import 'lyrics_edit_page.dart';

enum _GenerationStage {
  checkingNetwork,
  checkingLyricsService,
  checkingAi,
  generating,
  assembling,
  completed,
}

extension on _GenerationStage {
  String get label => switch (this) {
        _GenerationStage.checkingNetwork => '检查网络',
        _GenerationStage.checkingLyricsService => '检查歌词服务',
        _GenerationStage.checkingAi => '连接 AI 服务',
        _GenerationStage.generating => '生成注音与翻译',
        _GenerationStage.assembling => '整理生成结果',
        _GenerationStage.completed => '完成',
      };
}

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
  final _displayFocusNode = FocusNode();
  AiCancellationToken? _cancellationToken;
  LyricProcessingResult? _result;
  String? _error;
  String? _providerLabel;
  String? _configuredModel;
  bool _processing = false;
  bool _saving = false;
  Timer? _elapsedTimer;
  int _elapsedSeconds = 0;
  int _requestTimeoutSeconds = 0;
  _GenerationStage _stage = _GenerationStage.checkingNetwork;
  _GenerationStage? _failedStage;
  AiErrorKind? _aiErrorKind;
  LyricProcessingSession? _session;
  LyricProcessingProgress? _progress;

  @override
  void initState() {
    super.initState();
    _process();
  }

  Future<void> _process({bool retryFailedOnly = false}) async {
    if (_processing) return;
    _cancellationToken?.cancel();
    final token = AiCancellationToken();
    _cancellationToken = token;
    _elapsedTimer?.cancel();
    _elapsedSeconds = 0;
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _cancellationToken == token) {
        setState(() => _elapsedSeconds++);
      }
    });
    setState(() {
      _processing = true;
      _error = null;
      _failedStage = null;
      _aiErrorKind = null;
      _stage = _GenerationStage.checkingNetwork;
      if (!retryFailedOnly) {
        _result = null;
        _session = null;
        _progress = null;
      }
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
      await ref.read(networkConnectivityServiceProvider).checkInternetAccess();
      if (!mounted || token.isCancelled) return;
      setState(() => _stage = _GenerationStage.checkingLyricsService);

      await ref.read(lyricSearchServiceProvider).checkAvailability();
      if (!mounted || token.isCancelled) return;
      setState(() => _stage = _GenerationStage.checkingAi);

      await ref.read(openAiCompatibleClientProvider).testConnection(
            config: config,
            apiKey: apiKey,
            timeoutSeconds: 8,
            cancellationToken: token,
          );
      if (!mounted || token.isCancelled) return;

      final processor = ref.read(lyricAiProcessorProvider);
      final session = _session ?? processor.createSession(widget.rawLyrics);
      _session = session;
      _requestTimeoutSeconds = LyricAiProcessor.recommendedTimeoutSeconds(
        configuredSeconds: config.timeoutSeconds,
        rawLyrics: session.blocks.first.rawLyrics,
      );
      setState(() {
        _stage = _GenerationStage.generating;
        _progress = LyricProcessingProgress(
          completedBlocks: session.blocks
              .where((block) => block.status == LyricBlockStatus.succeeded)
              .length,
          failedBlocks: 0,
          totalBlocks: session.blocks.length,
        );
      });
      final result = await processor.processSession(
        session: session,
        config: config,
        apiKey: apiKey,
        title: widget.song.title,
        artist: widget.song.artist,
        cancellationToken: token,
        retryFailedOnly: retryFailedOnly,
        onProgress: (progress) {
          if (!mounted || token.isCancelled || _cancellationToken != token) {
            return;
          }
          setState(() {
            _progress = progress;
            if (progress.completedBlocks == progress.totalBlocks &&
                progress.failedBlocks == 0) {
              _stage = _GenerationStage.assembling;
            }
          });
        },
      );
      if (!mounted || token.isCancelled) return;
      _displayController.text = result.displayText;
      _translationController.text = result.translationText;
      setState(() {
        _result = result;
        _stage = _GenerationStage.completed;
      });
    } on NetworkConnectivityException catch (error) {
      if (!mounted || token.isCancelled) return;
      setState(() {
        _failedStage = _GenerationStage.checkingNetwork;
        _error = '网络连接失败\n\n${error.message}';
      });
    } on LyricSearchException catch (error) {
      if (!mounted || token.isCancelled) return;
      setState(() {
        _failedStage = _GenerationStage.checkingLyricsService;
        _error = '歌词服务连接失败\n\n${error.message}';
      });
    } on LyricChunkProcessingException catch (error) {
      if (!mounted || token.isCancelled) return;
      setState(() {
        _failedStage = _GenerationStage.generating;
        _error = error.message;
      });
    } on AiException catch (error) {
      if (!mounted || error.kind == AiErrorKind.cancelled) return;
      final errorStage = _stage == _GenerationStage.checkingNetwork &&
              (error.kind == AiErrorKind.invalidConfiguration ||
                  error.kind == AiErrorKind.authentication)
          ? _GenerationStage.checkingAi
          : _stage;
      setState(() {
        _aiErrorKind = error.kind;
        _failedStage = errorStage;
        _error = _friendlyAiError(error, errorStage);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'AI 处理失败，请重试或转为手动编辑');
    } finally {
      _elapsedTimer?.cancel();
      if (mounted && !token.isCancelled) {
        setState(() => _processing = false);
      }
    }
  }

  String _friendlyAiError(AiException error, _GenerationStage errorStage) {
    final title =
        errorStage == _GenerationStage.checkingAi ? 'AI 服务连接失败' : 'AI 歌词生成失败';
    final suggestion = switch (error.kind) {
      AiErrorKind.authentication => '请检查 API Key 与账号权限后重试。',
      AiErrorKind.endpoint => '请检查 Base URL 是否正确，且不要重复填写接口路径。',
      AiErrorKind.model => '请检查模型名称及当前账号的模型权限。',
      AiErrorKind.quota => '请检查账户余额或调用额度。',
      AiErrorKind.rateLimit => '请稍后仅重试失败的歌词块。',
      AiErrorKind.timeout => '请检查网络或代理，也可以改用响应更快的模型。',
      AiErrorKind.network => '请检查网络、DNS、代理和 API 地址。',
      AiErrorKind.server => '服务端暂时异常，请稍后重试。',
      AiErrorKind.invalidConfiguration => '请打开 AI 设置补全配置。',
      _ => '请重试；若持续失败，可转为手动编辑。',
    };
    return '$title\n\n${error.message}\n\n$suggestion';
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
      _selectDisplayLine(error.line);
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

  void _selectDisplayLine(int oneBasedLine) {
    final lines = _displayController.text.split('\n');
    if (oneBasedLine < 1 || oneBasedLine > lines.length) return;
    var start = 0;
    for (var index = 0; index < oneBasedLine - 1; index++) {
      start += lines[index].length + 1;
    }
    _displayController.selection = TextSelection(
      baseOffset: start,
      extentOffset: start + lines[oneBasedLine - 1].length,
    );
    _displayFocusNode.requestFocus();
  }

  int? _lineNumberFromMessage(String message) {
    final match = RegExp(r'第\s*(\d+)').firstMatch(message);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  @override
  void dispose() {
    _cancellationToken?.cancel();
    _elapsedTimer?.cancel();
    _displayController.dispose();
    _translationController.dispose();
    _displayFocusNode.dispose();
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
            Text(_stage.label),
            const SizedBox(height: 12),
            _buildStageList(),
            if (_stage == _GenerationStage.generating && _progress != null) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: _progress!.totalBlocks == 0
                    ? null
                    : (_progress!.completedBlocks + _progress!.failedBlocks) /
                        _progress!.totalBlocks,
              ),
              const SizedBox(height: 8),
              Text(
                '已完成 ${_progress!.completedBlocks} / '
                '${_progress!.totalBlocks} 个歌词块'
                '${_progress!.failedBlocks > 0 ? '，失败 ${_progress!.failedBlocks} 个' : ''}',
              ),
            ],
            const SizedBox(height: 12),
            Text(
              '已等待 $_elapsedSeconds 秒'
              '${_requestTimeoutSeconds > 0 ? '；单块最多等待 $_requestTimeoutSeconds 秒' : ''}。\n'
              '最多同时处理 ${LyricAiProcessor.defaultMaxConcurrency} 个块；完成前不会写入数据库。',
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

  Widget _buildStageList() {
    const stages = _GenerationStage.values;
    final currentIndex = stages.indexOf(_stage);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < stages.length; index++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  index < currentIndex
                      ? Icons.check_circle
                      : index == currentIndex
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                  size: 17,
                  color: index <= currentIndex
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(width: 7),
                SizedBox(width: 132, child: Text(stages[index].label)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildError() {
    final needsSettings = _aiErrorKind == AiErrorKind.invalidConfiguration ||
        _aiErrorKind == AiErrorKind.authentication ||
        _aiErrorKind == AiErrorKind.endpoint ||
        _aiErrorKind == AiErrorKind.model;
    final failedBlocks = _session?.failedBlocks.length ?? 0;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 44),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            if (_failedStage != null) ...[
              const SizedBox(height: 8),
              Text(
                '失败阶段：${_failedStage!.label}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 18),
            if (failedBlocks > 0)
              FilledButton(
                onPressed: () => _process(retryFailedOnly: true),
                child: Text('仅重试失败的 $failedBlocks 个歌词块'),
              )
            else if (needsSettings)
              FilledButton(
                onPressed: _openSettings,
                child: const Text('前往 AI 设置'),
              )
            else
              FilledButton(
                onPressed: () => _process(),
                child: const Text('重新检查并重试'),
              ),
            if (failedBlocks > 0)
              TextButton(
                onPressed: () => _process(),
                child: const Text('重新生成整首歌词'),
              ),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('请检查不确定项：'),
                  const SizedBox(height: 6),
                  for (final warning in result.warnings)
                    InkWell(
                      onTap: _lineNumberFromMessage(warning) == null
                          ? null
                          : () => _selectDisplayLine(
                                _lineNumberFromMessage(warning)!,
                              ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• '),
                            Expanded(child: Text(warning)),
                            if (_lineNumberFromMessage(warning) != null)
                              const Icon(Icons.my_location, size: 17),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
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
        LineNumberTextField(
          controller: _displayController,
          focusNode: _displayFocusNode,
          onChanged: (_) => setState(() {}),
          minLines: 10,
          maxLines: 20,
          labelText: '整理后的显示/注音歌词',
        ),
        const SizedBox(height: 14),
        LineNumberTextField(
          controller: _translationController,
          onChanged: (_) => setState(() {}),
          minLines: 8,
          maxLines: 20,
          labelText: '逐行中文翻译',
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => _process(),
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
