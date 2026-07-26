import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sing_list/ai/ai_config_repository.dart';
import 'package:sing_list/ai/ai_provider_config.dart';
import 'package:sing_list/service/settings_service.dart';

class MemoryApiKeyStore implements ApiKeyStore {
  String? value;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async => this.value = value;
}

void main() {
  test('persists non-sensitive config and keeps API key separate', () async {
    final directory = await Directory.systemTemp.createTemp('singlist_ai_');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/settings.json');
    final settings = SettingsService(settingsFileProvider: () async => file);
    final keyStore = MemoryApiKeyStore();
    final repository = AiConfigRepository(settings, keyStore);
    const config = AiProviderConfig(
      provider: AiProvider.openAi,
      baseUrl: 'https://example.com/v1',
      model: 'custom-model',
      timeoutSeconds: 45,
      enabled: true,
    );

    await repository.saveConfig(config);
    await repository.saveApiKey('super-secret');

    final loaded = await repository.loadConfig();
    expect(loaded.provider, AiProvider.openAi);
    expect(loaded.model, 'custom-model');
    expect(await repository.readApiKey(), 'super-secret');
    expect(await file.readAsString(), isNot(contains('super-secret')));

    await repository.clearApiKey();
    expect(await repository.readApiKey(), isNull);
  });
}
