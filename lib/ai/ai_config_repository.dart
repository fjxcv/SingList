import 'ai_provider_config.dart';

abstract interface class AiConfigStore {
  Future<Map<String, dynamic>?> loadAiConfig();
  Future<void> saveAiConfig(Map<String, dynamic> config);
}

abstract interface class ApiKeyStore {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> clear();
}

class AiConfigRepository {
  AiConfigRepository(this.configStore, this.apiKeyStore);

  final AiConfigStore configStore;
  final ApiKeyStore apiKeyStore;

  Future<AiProviderConfig> loadConfig() async {
    final json = await configStore.loadAiConfig();
    return json == null
        ? AiProviderConfig.presetFor(AiProvider.deepSeek)
        : AiProviderConfig.fromJson(json);
  }

  Future<void> saveConfig(AiProviderConfig config) {
    return configStore.saveAiConfig(config.toJson());
  }

  Future<String?> readApiKey() => apiKeyStore.read();

  Future<void> saveApiKey(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      await apiKeyStore.clear();
    } else {
      await apiKeyStore.write(trimmed);
    }
  }

  Future<void> clearApiKey() => apiKeyStore.clear();
}
