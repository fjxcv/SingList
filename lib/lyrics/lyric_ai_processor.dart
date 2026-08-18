import 'dart:convert';

import '../ai/ai_exception.dart';
import '../ai/ai_provider_config.dart';
import '../ai/openai_compatible_client.dart';
import 'ai_furigana_normalizer.dart';
import 'furigana_parser.dart';
import 'lyric_ai_prompt.dart';
import 'lyric_processing_result.dart';
import 'lyric_search_service.dart';

enum LyricBlockStatus { pending, processing, succeeded, failed }

class LyricProcessingBlock {
  LyricProcessingBlock({
    required this.index,
    required this.startLine,
    required this.sourceLines,
  });

  final int index;
  final int startLine;
  final List<String> sourceLines;
  LyricBlockStatus status = LyricBlockStatus.pending;
  LyricProcessingResult? result;
  AiException? error;
  int attempts = 0;

  int get endLine => startLine + sourceLines.length - 1;
  String get rawLyrics => sourceLines.join('\n');
}

class LyricProcessingSession {
  LyricProcessingSession(
      {required this.normalizedLyrics, required this.blocks});

  final String normalizedLyrics;
  final List<LyricProcessingBlock> blocks;

  List<LyricProcessingBlock> get failedBlocks => blocks
      .where((block) => block.status == LyricBlockStatus.failed)
      .toList(growable: false);
}

class LyricProcessingProgress {
  const LyricProcessingProgress({
    required this.completedBlocks,
    required this.failedBlocks,
    required this.totalBlocks,
  });

  final int completedBlocks;
  final int failedBlocks;
  final int totalBlocks;
}

class LyricChunkProcessingException implements Exception {
  const LyricChunkProcessingException(this.failedBlocks);

  final List<LyricProcessingBlock> failedBlocks;

  String get message {
    final details = failedBlocks.map((block) {
      final range = block.startLine == block.endLine
          ? '第 ${block.startLine} 行'
          : '第 ${block.startLine}～${block.endLine} 行';
      return '$range：${block.error?.message ?? '处理失败'}';
    }).join('\n');
    return '有 ${failedBlocks.length} 个歌词块处理失败，已保留其余成功结果。\n$details';
  }

  @override
  String toString() => message;
}

class LyricAiProcessor {
  const LyricAiProcessor(this.client);

  final OpenAiCompatibleClient client;

  static const int defaultChunkSize = 12;
  static const int defaultMaxConcurrency = 3;
  static const int _automaticAttemptsPerRun = 2;

  static int recommendedTimeoutSeconds({
    required int configuredSeconds,
    required String rawLyrics,
  }) {
    final lineCount = rawLyrics.split('\n').length;
    final characterCount = rawLyrics.runes.length;
    final estimatedSeconds = 45 + lineCount * 2 + characterCount ~/ 16;
    final boundedEstimate = estimatedSeconds.clamp(45, 180);
    return configuredSeconds > boundedEstimate
        ? configuredSeconds
        : boundedEstimate;
  }

  Future<LyricProcessingResult> process({
    required AiProviderConfig config,
    required String apiKey,
    required String title,
    required String artist,
    required String rawLyrics,
    AiCancellationToken? cancellationToken,
  }) async {
    final session = createSession(rawLyrics);
    return processSession(
      session: session,
      config: config,
      apiKey: apiKey,
      title: title,
      artist: artist,
      cancellationToken: cancellationToken,
    );
  }

  LyricProcessingSession createSession(
    String rawLyrics, {
    int chunkSize = defaultChunkSize,
  }) {
    if (chunkSize <= 0) {
      throw ArgumentError.value(chunkSize, 'chunkSize', '必须大于 0');
    }
    final normalized = LyricSearchService.normalizeLyrics(rawLyrics);
    if (normalized.trim().isEmpty) {
      throw const AiException(
        AiErrorKind.invalidConfiguration,
        '原始歌词不能为空',
      );
    }
    final lines = normalized.split('\n');
    final blocks = <LyricProcessingBlock>[];
    for (var offset = 0; offset < lines.length; offset += chunkSize) {
      final end = (offset + chunkSize).clamp(0, lines.length);
      blocks.add(
        LyricProcessingBlock(
          index: blocks.length,
          startLine: offset + 1,
          sourceLines: List.unmodifiable(lines.sublist(offset, end)),
        ),
      );
    }
    return LyricProcessingSession(
      normalizedLyrics: normalized,
      blocks: blocks,
    );
  }

  Future<LyricProcessingResult> processSession({
    required LyricProcessingSession session,
    required AiProviderConfig config,
    required String apiKey,
    required String title,
    required String artist,
    AiCancellationToken? cancellationToken,
    int maxConcurrency = defaultMaxConcurrency,
    bool retryFailedOnly = false,
    void Function(LyricProcessingProgress progress)? onProgress,
  }) async {
    if (maxConcurrency <= 0) {
      throw ArgumentError.value(
        maxConcurrency,
        'maxConcurrency',
        '必须大于 0',
      );
    }
    final targets = retryFailedOnly
        ? session.blocks
            .where((block) => block.status == LyricBlockStatus.failed)
            .toList()
        : session.blocks.toList();
    if (!retryFailedOnly) {
      for (final block in targets) {
        block
          ..status = LyricBlockStatus.pending
          ..result = null
          ..error = null;
      }
    }
    if (targets.isEmpty) return _mergeSession(session);

    void reportProgress() {
      onProgress?.call(
        LyricProcessingProgress(
          completedBlocks: session.blocks
              .where((block) => block.status == LyricBlockStatus.succeeded)
              .length,
          failedBlocks: session.blocks
              .where((block) => block.status == LyricBlockStatus.failed)
              .length,
          totalBlocks: session.blocks.length,
        ),
      );
    }

    var nextTarget = 0;
    Future<void> worker() async {
      while (true) {
        if (cancellationToken?.isCancelled == true) {
          throw const AiException(AiErrorKind.cancelled, '操作已取消');
        }
        if (nextTarget >= targets.length) return;
        final block = targets[nextTarget++];
        block
          ..status = LyricBlockStatus.processing
          ..error = null;
        reportProgress();

        AiException? lastError;
        for (var attempt = 0; attempt < _automaticAttemptsPerRun; attempt++) {
          block.attempts++;
          try {
            block.result = await _processBlock(
              block: block,
              config: config,
              apiKey: apiKey,
              title: title,
              artist: artist,
              cancellationToken: cancellationToken,
            );
            block.status = LyricBlockStatus.succeeded;
            lastError = null;
            break;
          } on AiException catch (error) {
            if (error.kind == AiErrorKind.cancelled) rethrow;
            if (!_isRetryable(error)) rethrow;
            lastError = error;
            if (attempt == _automaticAttemptsPerRun - 1) {
              break;
            }
          }
        }
        if (lastError != null) {
          block
            ..status = LyricBlockStatus.failed
            ..error = lastError;
        }
        reportProgress();
      }
    }

    final workerCount =
        maxConcurrency < targets.length ? maxConcurrency : targets.length;
    await Future.wait(List.generate(workerCount, (_) => worker()));
    if (cancellationToken?.isCancelled == true) {
      throw const AiException(AiErrorKind.cancelled, '操作已取消');
    }
    final failed = session.failedBlocks;
    if (failed.isNotEmpty) {
      throw LyricChunkProcessingException(failed);
    }
    return _mergeSession(session);
  }

  Future<LyricProcessingResult> _processBlock({
    required LyricProcessingBlock block,
    required AiProviderConfig config,
    required String apiKey,
    required String title,
    required String artist,
    AiCancellationToken? cancellationToken,
  }) async {
    final response = await client.complete(
      config: config,
      apiKey: apiKey,
      messages: LyricAiPrompt.messages(
        title: title,
        artist: artist,
        rawLyrics: block.rawLyrics,
      ),
      temperature: 0.1,
      timeoutSeconds: recommendedTimeoutSeconds(
        configuredSeconds: config.timeoutSeconds,
        rawLyrics: block.rawLyrics,
      ),
      cancellationToken: cancellationToken,
    );
    return parseAndValidate(
      response.content,
      originalLyrics: block.rawLyrics,
      actualModel: response.model,
      lineNumberOffset: block.startLine - 1,
    );
  }

  bool _isRetryable(AiException error) => switch (error.kind) {
        AiErrorKind.timeout ||
        AiErrorKind.network ||
        AiErrorKind.server ||
        AiErrorKind.rateLimit ||
        AiErrorKind.invalidResponse =>
          true,
        _ => false,
      };

  LyricProcessingResult _mergeSession(LyricProcessingSession session) {
    final orderedBlocks = [...session.blocks]
      ..sort((left, right) => left.index.compareTo(right.index));
    if (orderedBlocks.any((block) => block.result == null)) {
      throw const AiException(
        AiErrorKind.invalidResponse,
        '歌词块尚未全部处理完成',
      );
    }
    final results = orderedBlocks.map((block) => block.result!).toList();
    final lines = results.expand((result) => result.lines).toList()
      ..sort((left, right) => left.index.compareTo(right.index));
    if (lines.length != session.normalizedLyrics.split('\n').length) {
      throw const AiException(
        AiErrorKind.invalidResponse,
        '合并后的歌词行数与原歌词不一致',
      );
    }
    final languages = results.map((result) => result.language).toSet();
    final warnings = <String>[
      for (var index = 0; index < results.length; index++)
        for (final warning in results[index].warnings)
          _warningWithGlobalLine(warning, orderedBlocks[index]),
      if (languages.length > 1) '不同歌词块的语言识别结果不一致，请人工确认。',
    ];
    return LyricProcessingResult(
      language: results.first.language,
      lines: lines,
      warnings: warnings,
      actualModel: results.first.actualModel,
    );
  }

  String _warningWithGlobalLine(
    String warning,
    LyricProcessingBlock block,
  ) {
    final match = RegExp(r'第\s*(\d+)\s*行').firstMatch(warning);
    if (match != null) {
      final localLine = int.tryParse(match.group(1)!);
      if (localLine != null && localLine >= 1) {
        final globalLine = block.startLine + localLine - 1;
        return warning.replaceRange(
          match.start,
          match.end,
          '第 $globalLine 行',
        );
      }
    }
    final range = block.startLine == block.endLine
        ? '第 ${block.startLine} 行'
        : '第 ${block.startLine}～${block.endLine} 行';
    return '$range：$warning';
  }

  LyricProcessingResult parseAndValidate(
    String content, {
    required String originalLyrics,
    required String actualModel,
    int lineNumberOffset = 0,
  }) {
    final jsonText = _stripMarkdownFence(content);
    late final dynamic decoded;
    try {
      decoded = jsonDecode(jsonText);
    } on FormatException {
      throw const AiException(
        AiErrorKind.invalidResponse,
        'AI 返回了非法 JSON，请重试',
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const AiException(
        AiErrorKind.invalidResponse,
        'AI 返回的 JSON 不是对象',
      );
    }
    final language = decoded['language'];
    final rawLines = decoded['lines'];
    if (language is! String || rawLines is! List) {
      throw const AiException(
        AiErrorKind.invalidResponse,
        'AI 返回缺少 language 或 lines',
      );
    }
    final originals = originalLyrics.split('\n');
    if (rawLines.length != originals.length) {
      throw const AiException(
        AiErrorKind.invalidResponse,
        'AI 返回行数与原歌词不一致，已拒绝结果',
      );
    }
    final lines = <ProcessedLyricLine>[];
    final seenIndexes = <int>{};
    final normalizedLanguage = language.trim().toLowerCase();
    final isJapanese = normalizedLanguage == 'ja' ||
        normalizedLanguage == 'jp' ||
        normalizedLanguage.startsWith('ja-') ||
        normalizedLanguage == 'japanese' ||
        normalizedLanguage == '日本語';
    for (var position = 0; position < rawLines.length; position++) {
      final value = rawLines[position];
      if (value is! Map) {
        throw const AiException(
          AiErrorKind.invalidResponse,
          'AI 返回的歌词行格式不正确',
        );
      }
      final index = value['index'];
      final returnedOriginal = value['original'];
      final rawDisplay = value['display'];
      final translation = value['translation'];
      if (index is! int ||
          returnedOriginal != null && returnedOriginal is! String ||
          rawDisplay is! String ||
          translation is! String) {
        throw const AiException(
          AiErrorKind.invalidResponse,
          'AI 返回的歌词字段类型不正确',
        );
      }
      if (index != position || !seenIndexes.add(index)) {
        throw const AiException(
          AiErrorKind.invalidResponse,
          'AI 返回的 index 缺失、重复或不连续',
        );
      }
      final original = originals[position];
      if (returnedOriginal is String && returnedOriginal != original) {
        throw AiException(
          AiErrorKind.invalidResponse,
          'AI 修改了第 ${lineNumberOffset + position + 1} 行原歌词，已拒绝结果',
        );
      }
      final display = isJapanese
          ? const AiFuriganaNormalizer().normalize(rawDisplay)
          : rawDisplay;
      if (original.isNotEmpty && display.isEmpty) {
        throw AiException(
          AiErrorKind.invalidResponse,
          'AI 删除了第 ${lineNumberOffset + position + 1} 行显示歌词，已拒绝结果',
        );
      }
      if (isJapanese &&
          original.trim().isNotEmpty &&
          translation.trim().isEmpty) {
        throw AiException(
          AiErrorKind.invalidResponse,
          'AI 未生成第 ${lineNumberOffset + position + 1} 行的中文翻译，请重试',
        );
      }
      final furiganaError = const FuriganaParser().validate(display);
      if (furiganaError != null) {
        throw AiException(
          AiErrorKind.invalidResponse,
          'AI 返回的第 ${lineNumberOffset + position + 1} 行，'
          '第 ${furiganaError.column} 列注音格式错误：${furiganaError.message}',
        );
      }
      lines.add(
        ProcessedLyricLine(
          index: lineNumberOffset + index,
          original: original,
          display: display,
          translation: translation,
        ),
      );
    }
    final warningsValue = decoded['warnings'];
    final warnings = warningsValue is List
        ? warningsValue.whereType<String>().toList()
        : const <String>[];
    return LyricProcessingResult(
      language: language,
      lines: lines,
      warnings: warnings,
      actualModel: actualModel,
    );
  }

  String _stripMarkdownFence(String value) {
    final trimmed = value.trim();
    final match = RegExp(
      r'^```(?:json)?\s*([\s\S]*?)\s*```$',
      caseSensitive: false,
    ).firstMatch(trimmed);
    return match?.group(1)?.trim() ?? trimmed;
  }
}
