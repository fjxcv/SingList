import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'ai_exception.dart';
import 'ai_provider_config.dart';

class AiChatResponse {
  const AiChatResponse({required this.content, required this.model});

  final String content;
  final String model;
}

class AiCancellationToken {
  final _cancelled = Completer<void>();

  bool get isCancelled => _cancelled.isCompleted;
  Future<void> get whenCancelled => _cancelled.future;

  void cancel() {
    if (!_cancelled.isCompleted) _cancelled.complete();
  }
}

class OpenAiCompatibleClient {
  OpenAiCompatibleClient({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  static Uri chatCompletionsUri(String baseUrl) {
    final trimmed = baseUrl.trim();
    if (trimmed.isEmpty) {
      throw const AiException(
        AiErrorKind.invalidConfiguration,
        '请填写 Base URL',
      );
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw const AiException(
        AiErrorKind.invalidConfiguration,
        'Base URL 格式不正确',
      );
    }
    final segments = [...uri.pathSegments.where((part) => part.isNotEmpty)];
    if (segments.length < 2 ||
        segments[segments.length - 2] != 'chat' ||
        segments.last != 'completions') {
      segments.addAll(['chat', 'completions']);
    }
    return uri.replace(pathSegments: segments, query: null, fragment: null);
  }

  static Uri modelsUri(String baseUrl) {
    final chatUri = chatCompletionsUri(baseUrl);
    final segments = [...chatUri.pathSegments.where((part) => part.isNotEmpty)];
    if (segments.length >= 2 &&
        segments[segments.length - 2] == 'chat' &&
        segments.last == 'completions') {
      segments.removeRange(segments.length - 2, segments.length);
    }
    segments.add('models');
    return chatUri.replace(pathSegments: segments);
  }

  Future<AiChatResponse> complete({
    required AiProviderConfig config,
    required String apiKey,
    required List<Map<String, String>> messages,
    double temperature = 0.1,
    int? maxTokens,
    int? timeoutSeconds,
    AiCancellationToken? cancellationToken,
    bool allowEmptyContent = false,
  }) async {
    if (!config.enabled) {
      throw const AiException(
        AiErrorKind.invalidConfiguration,
        'AI 服务尚未启用',
      );
    }
    if (config.model.trim().isEmpty) {
      throw const AiException(
        AiErrorKind.invalidConfiguration,
        '请填写模型名',
      );
    }
    if (apiKey.trim().isEmpty) {
      throw const AiException(
        AiErrorKind.authentication,
        '请先填写 API Key',
      );
    }

    final body = <String, dynamic>{
      'model': config.model.trim(),
      'messages': messages,
      'temperature': temperature,
      if (maxTokens != null) 'max_tokens': maxTokens,
    };

    try {
      final request = _httpClient.post(
        chatCompletionsUri(config.baseUrl),
        headers: {
          'Authorization': 'Bearer ${apiKey.trim()}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
      final timeout = Completer<http.Response>();
      final effectiveTimeoutSeconds = timeoutSeconds ?? config.timeoutSeconds;
      final timeoutTimer = Timer(
        Duration(seconds: effectiveTimeoutSeconds),
        () => timeout.completeError(TimeoutException('AI request timed out')),
      );
      late final http.Response response;
      try {
        response = await Future.any([
          request,
          timeout.future,
          if (cancellationToken != null)
            cancellationToken.whenCancelled.then<http.Response>(
              (_) => throw const AiException(
                AiErrorKind.cancelled,
                '操作已取消',
              ),
            ),
        ]);
      } finally {
        timeoutTimer.cancel();
      }
      if (cancellationToken?.isCancelled == true) {
        throw const AiException(AiErrorKind.cancelled, '操作已取消');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _httpError(response);
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const AiException(
          AiErrorKind.invalidResponse,
          'AI 返回格式不受支持',
        );
      }
      final choices = decoded['choices'];
      final model = decoded['model'];
      if (choices is! List || choices.isEmpty || choices.first is! Map) {
        throw const AiException(
          AiErrorKind.invalidResponse,
          'AI 返回中缺少 choices',
        );
      }
      final choice = choices.first as Map;
      final message = choice['message'];
      if (message is! Map) {
        throw const AiException(
          AiErrorKind.invalidResponse,
          'AI 返回中缺少 message',
        );
      }
      final content = _extractTextContent(message['content']);
      if (content.isEmpty && !allowEmptyContent) {
        if (choice['finish_reason'] == 'length') {
          throw const AiException(
            AiErrorKind.invalidResponse,
            'AI 输出达到长度限制，未返回正文，请提高输出 Token 上限后重试',
          );
        }
        throw const AiException(
          AiErrorKind.invalidResponse,
          'AI 返回中缺少文本内容',
        );
      }
      return AiChatResponse(
        content: content,
        model: model is String ? model : config.model,
      );
    } on TimeoutException {
      final effectiveTimeoutSeconds = timeoutSeconds ?? config.timeoutSeconds;
      throw AiException(
        AiErrorKind.timeout,
        '请求超过 $effectiveTimeoutSeconds 秒仍未完成。'
        '长歌词或推理模型需要更久，可重试、缩短歌词，或改用更快的模型。',
      );
    } on SocketException {
      throw const AiException(AiErrorKind.network, '无网络或无法连接到服务');
    } on http.ClientException {
      throw const AiException(AiErrorKind.network, '网络请求失败');
    } on FormatException {
      throw const AiException(
        AiErrorKind.invalidResponse,
        '服务返回了无法解析的数据',
      );
    }
  }

  AiException _httpError(http.Response response) {
    final body = response.body.toLowerCase();
    if (response.statusCode == 401 || response.statusCode == 403) {
      return AiException(
        AiErrorKind.authentication,
        'API Key 无效、无权限或服务拒绝访问',
        statusCode: response.statusCode,
      );
    }
    if ((response.statusCode == 400 || response.statusCode == 404) &&
        body.contains('model')) {
      return AiException(
        AiErrorKind.model,
        '模型不存在或当前账号无权使用',
        statusCode: response.statusCode,
      );
    }
    if (response.statusCode == 404) {
      return AiException(
        AiErrorKind.endpoint,
        'Base URL 或接口路径不正确',
        statusCode: response.statusCode,
      );
    }
    if (response.statusCode == 402 ||
        response.statusCode == 429 &&
            (body.contains('quota') ||
                body.contains('balance') ||
                body.contains('billing'))) {
      return AiException(
        AiErrorKind.quota,
        '余额或调用额度不足',
        statusCode: response.statusCode,
      );
    }
    if (response.statusCode == 429) {
      return const AiException(
        AiErrorKind.rateLimit,
        'AI 请求过于频繁，已触发速率限制，请稍后重试',
        statusCode: 429,
      );
    }
    if (response.statusCode >= 500) {
      return AiException(
        AiErrorKind.server,
        'AI 服务端错误，请稍后重试',
        statusCode: response.statusCode,
      );
    }
    return AiException(
      AiErrorKind.server,
      'AI 请求失败（HTTP ${response.statusCode}）',
      statusCode: response.statusCode,
    );
  }

  Future<AiChatResponse> testConnection({
    required AiProviderConfig config,
    required String apiKey,
    int timeoutSeconds = 8,
    AiCancellationToken? cancellationToken,
  }) async {
    if (!config.enabled) {
      throw const AiException(
        AiErrorKind.invalidConfiguration,
        'AI 服务尚未启用',
      );
    }
    if (config.model.trim().isEmpty) {
      throw const AiException(
        AiErrorKind.invalidConfiguration,
        '请填写模型名',
      );
    }
    if (apiKey.trim().isEmpty) {
      throw const AiException(
        AiErrorKind.authentication,
        '请先填写 API Key',
      );
    }

    try {
      final request = _httpClient.get(
        modelsUri(config.baseUrl),
        headers: {
          'Authorization': 'Bearer ${apiKey.trim()}',
          'Accept': 'application/json',
        },
      );
      final response = await Future.any<http.Response>([
        request,
        Future<http.Response>.delayed(
          Duration(seconds: timeoutSeconds),
          () => throw TimeoutException('AI connection check timed out'),
        ),
        if (cancellationToken != null)
          cancellationToken.whenCancelled.then<http.Response>(
            (_) => throw const AiException(
              AiErrorKind.cancelled,
              '操作已取消',
            ),
          ),
      ]);
      if (cancellationToken?.isCancelled == true) {
        throw const AiException(AiErrorKind.cancelled, '操作已取消');
      }
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return AiChatResponse(content: '', model: config.model);
      }
      if (response.statusCode != 400 &&
          response.statusCode != 404 &&
          response.statusCode != 405) {
        throw _httpError(response);
      }

      // 少数兼容服务没有 /models；只在端点明确不支持时退化为极小请求。
      return complete(
        config: config,
        apiKey: apiKey,
        messages: const [
          {'role': 'user', 'content': 'Reply only with OK.'},
        ],
        temperature: 0,
        maxTokens: 16,
        timeoutSeconds: timeoutSeconds,
        cancellationToken: cancellationToken,
        allowEmptyContent: true,
      );
    } on TimeoutException {
      throw AiException(
        AiErrorKind.timeout,
        'AI 服务连接检查超过 $timeoutSeconds 秒，请检查网络、代理或 API 地址',
      );
    } on SocketException {
      throw const AiException(
        AiErrorKind.network,
        '无法连接 AI 服务，请检查网络、DNS、代理或 Base URL',
      );
    } on http.ClientException {
      throw const AiException(
        AiErrorKind.network,
        'AI 服务网络请求失败，请检查网络或 API 地址',
      );
    }
  }

  static String _extractTextContent(dynamic content) {
    if (content is String) return content.trim();
    if (content is! List) return '';

    return content
        .map((part) {
          if (part is String) return part;
          if (part is Map && part['text'] is String) {
            return part['text'] as String;
          }
          return '';
        })
        .where((part) => part.isNotEmpty)
        .join()
        .trim();
  }
}
