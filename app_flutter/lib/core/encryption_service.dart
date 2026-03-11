import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart' hide Key;

class EncryptionService {
  // 32-byte key for AES-256 (Shared across instances for portability)
  static final _key =
      enc.Key.fromUtf8('PdSoftphone_SecretKey_2026_V1_!!'); // 32 chars
  // 16-byte fixed IV (Ensures same ciphertext for same plaintext across instances)
  static final _iv = enc.IV.fromUtf8('PdSoft_Fixed_IV_');

  static final _encrypter = enc.Encrypter(enc.AES(_key, mode: enc.AESMode.cbc));

  /// Encrypt a string and return a Base64 string.
  static String encrypt(String plainText) {
    if (plainText.isEmpty) return '';
    try {
      final encrypted = _encrypter.encrypt(plainText, iv: _iv);
      return encrypted.base64;
    } catch (e) {
      debugPrint('[EncryptionService] Encryption error: $e');
      return plainText; // Fallback
    }
  }

  /// Decrypt a Base64 string.
  static String decrypt(String base64Text) {
    if (base64Text.isEmpty) return '';
    if (!_looksLikeEncryptedBase64(base64Text)) {
      return base64Text;
    }
    try {
      final decrypted = _encrypter.decrypt64(base64Text, iv: _iv);
      return decrypted;
    } catch (e) {
      debugPrint('[EncryptionService] Decryption error: $e');
      return base64Text;
    }
  }

  static bool _looksLikeEncryptedBase64(String value) {
    final trimmed = value.trim();
    if (trimmed.length < 24 || trimmed.length % 4 != 0) {
      return false;
    }
    return RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(trimmed);
  }
}
