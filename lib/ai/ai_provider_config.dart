enum AiProvider {
  deepSeek,
  qwen,
  xiaomiMimo,
  openAi,
  custom,
}

class AiProviderConfig {
  const AiProviderConfig({
    required this.provider,
    required this.baseUrl,
    required this.model,
    this.timeoutSeconds = 60,
    this.enabled = false,
  });

  final AiProvider provider;
  final String baseUrl;
  final String model;
  final int timeoutSeconds;
  final bool enabled;

  String get providerLabel => switch (provider) {
        AiProvider.deepSeek => 'DeepSeek',
        AiProvider.qwen => '通义千问',
        AiProvider.xiaomiMimo => 'Xiaomi MiMo',
        AiProvider.openAi => 'OpenAI',
        AiProvider.custom => '自定义兼容接口',
      };

  AiProviderConfig copyWith({
    AiProvider? provider,
    String? baseUrl,
    String? model,
    int? timeoutSeconds,
    bool? enabled,
  }) {
    return AiProviderConfig(
      provider: provider ?? this.provider,
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
      timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'provider': provider.name,
        'baseUrl': baseUrl,
        'model': model,
        'timeoutSeconds': timeoutSeconds,
        'enabled': enabled,
      };

  factory AiProviderConfig.fromJson(Map<String, dynamic> json) {
    final providerName = json['provider'] as String?;
    final provider = AiProvider.values.firstWhere(
      (item) => item.name == providerName,
      orElse: () => AiProvider.deepSeek,
    );
    final fallback = presetFor(provider);
    return AiProviderConfig(
      provider: provider,
      baseUrl: json['baseUrl'] as String? ?? fallback.baseUrl,
      model: json['model'] as String? ?? fallback.model,
      timeoutSeconds: json['timeoutSeconds'] as int? ?? 60,
      enabled: json['enabled'] as bool? ?? false,
    );
  }

  static AiProviderConfig presetFor(AiProvider provider) {
    return switch (provider) {
      AiProvider.deepSeek => const AiProviderConfig(
          provider: AiProvider.deepSeek,
          baseUrl: 'https://api.deepseek.com',
          model: 'deepseek-v4-flash',
        ),
      AiProvider.qwen => const AiProviderConfig(
          provider: AiProvider.qwen,
          baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
          model: 'qwen-plus',
        ),
      AiProvider.xiaomiMimo => const AiProviderConfig(
          provider: AiProvider.xiaomiMimo,
          baseUrl: 'https://api.xiaomimimo.com/v1',
          model: 'mimo-v2.5-pro',
        ),
      AiProvider.openAi => const AiProviderConfig(
          provider: AiProvider.openAi,
          baseUrl: 'https://api.openai.com/v1',
          model: '',
        ),
      AiProvider.custom => const AiProviderConfig(
          provider: AiProvider.custom,
          baseUrl: '',
          model: '',
        ),
    };
  }
}
