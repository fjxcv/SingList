import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'ai_config_repository.dart';

class FlutterSecureApiKeyStore implements ApiKeyStore {
  FlutterSecureApiKeyStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'singlist.ai.api_key';
  final FlutterSecureStorage _storage;

  @override
  Future<void> clear() => _storage.delete(key: _key);

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String value) => _storage.write(key: _key, value: value);
}
