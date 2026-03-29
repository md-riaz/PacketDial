import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../interfaces/secure_secrets_store.dart';

class FlutterSecureSecretsStore implements SecureSecretsStore {
  FlutterSecureSecretsStore({
    FlutterSecureStorage? storage,
    required SecureSecretsStore fallback,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _fallback = fallback;

  final FlutterSecureStorage _storage;
  final SecureSecretsStore _fallback;

  @override
  Future<void> deleteSipPassword(String accountId) async {
    try {
      await _storage.delete(key: accountId);
    } catch (_) {
      await _fallback.deleteSipPassword(accountId);
    }
  }

  @override
  Future<String?> readSipPassword(String accountId) async {
    try {
      return await _storage.read(key: accountId);
    } catch (_) {
      return _fallback.readSipPassword(accountId);
    }
  }

  @override
  Future<void> writeSipPassword(String accountId, String value) async {
    try {
      await _storage.write(key: accountId, value: value);
    } catch (_) {
      await _fallback.writeSipPassword(accountId, value);
    }
  }
}
