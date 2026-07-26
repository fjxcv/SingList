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

  Future<AiChatResponse> complete({
    required AiProviderConfig config,
    required String apiKey,
    required List<Map<String, String>> messages,
    double temperature = 0.1,
    int? maxTokens,
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
      final request = _httpClient
          .post(
            chatCompletionsUri(config.baseUrl),
            headers: {
              'Authorization': 'Bearer ${apiKey.trim()}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(Duration(seconds: config.timeoutSeconds));
      final response = cancellationToken == null
          ? await request
          : await Future.any([
              request,
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
      throw const AiException(AiErrorKind.timeout, '请求超时，请稍后重试');
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
  }) {
    return complete(
      config: config,
      apiKey: apiKey,
      messages: const [
        {'role': 'user', 'content': 'Reply only with OK.'},
      ],
      temperature: 0,
      maxTokens: 256,
      // 测试连接只验证凭证、地址、模型和响应结构。部分推理模型会把
      // 较短请求的输出全部放入 reasoning_content，message.content 为空。
      allowEmptyContent: true,
    );
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
