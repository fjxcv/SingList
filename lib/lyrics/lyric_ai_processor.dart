import 'dart:convert';

import '../ai/ai_exception.dart';
import '../ai/ai_provider_config.dart';
import '../ai/openai_compatible_client.dart';
import 'furigana_parser.dart';
import 'lyric_ai_prompt.dart';
import 'lyric_processing_result.dart';
import 'lyric_search_service.dart';

class LyricAiProcessor {
  const LyricAiProcessor(this.client);

  final OpenAiCompatibleClient client;

  Future<LyricProcessingResult> process({
    required AiProviderConfig config,
    required String apiKey,
    required String title,
    required String artist,
    required String rawLyrics,
    AiCancellationToken? cancellationToken,
  }) async {
    final normalized = LyricSearchService.normalizeLyrics(rawLyrics);
    if (normalized.trim().isEmpty) {
      throw const AiException(
        AiErrorKind.invalidConfiguration,
        '原始歌词不能为空',
      );
    }
    final response = await client.complete(
      config: config,
      apiKey: apiKey,
      messages: LyricAiPrompt.messages(
        title: title,
        artist: artist,
        rawLyrics: normalized,
      ),
      temperature: 0.1,
      cancellationToken: cancellationToken,
    );
    return parseAndValidate(
      response.content,
      originalLyrics: normalized,
      actualModel: response.model,
    );
  }

  LyricProcessingResult parseAndValidate(
    String content, {
    required String originalLyrics,
    required String actualModel,
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
      final original = value['original'];
      final display = value['display'];
      final translation = value['translation'];
      if (index is! int ||
          original is! String ||
          display is! String ||
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
      if (original != originals[position]) {
        throw AiException(
          AiErrorKind.invalidResponse,
          'AI 修改了第 ${position + 1} 行原歌词，已拒绝结果',
        );
      }
      if (original.isNotEmpty && display.isEmpty) {
        throw AiException(
          AiErrorKind.invalidResponse,
          'AI 删除了第 ${position + 1} 行显示歌词，已拒绝结果',
        );
      }
      if (isJapanese &&
          original.trim().isNotEmpty &&
          translation.trim().isEmpty) {
        throw AiException(
          AiErrorKind.invalidResponse,
          'AI 未生成第 ${position + 1} 行的中文翻译，请重试',
        );
      }
      final furiganaError = const FuriganaParser().validate(display);
      if (furiganaError != null) {
        throw AiException(
          AiErrorKind.invalidResponse,
          'AI 返回的第 ${position + 1} 行注音格式错误：$furiganaError',
        );
      }
      lines.add(
        ProcessedLyricLine(
          index: index,
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
