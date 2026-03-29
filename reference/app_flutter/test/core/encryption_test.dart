import 'package:flutter_test/flutter_test.dart';
import 'package:voip_softphone/core/encryption_service.dart';
import 'package:voip_softphone/models/account_schema.dart';

void main() {
  group('EncryptionService Tests', () {
    test('Encryption and Decryption should be reversible', () {
      const plainText = 'MySecretP@ssword123';
      final encrypted = EncryptionService.encrypt(plainText);
      final decrypted = EncryptionService.decrypt(encrypted);

      expect(encrypted, isNot(equals(plainText)));
      expect(decrypted, equals(plainText));
    });

    test('Encryption should be deterministic (same input = same output)', () {
      const plainText = 'constant_password';
      final encrypted1 = EncryptionService.encrypt(plainText);
      final encrypted2 = EncryptionService.encrypt(plainText);

      expect(encrypted1, equals(encrypted2));
    });

    test('Decryption should handle plain text gracefully', () {
      const plainText = 'LegacyPlainText';
      // If text is not Base64 or not encrypted correctly, it returns as is
      final result = EncryptionService.decrypt(plainText);
      expect(result, equals(plainText));
    });

    test('Encryption should handle empty strings', () {
      expect(EncryptionService.encrypt(''), equals(''));
      expect(EncryptionService.decrypt(''), equals(''));
    });

    test('AccountSchema.fromJson should respect plain_pass override', () {
      final json = {
        'uuid': 'test-uuid',
        'password': 'SomeEncryptedGibberish',
        'plain_pass': 'ManualOverride123',
      };

      // We don't need a full valid JSON for this specific test logic
      final schema = AccountSchema.fromJson(json);
      expect(schema.password, equals('ManualOverride123'));
    });

    test('AccountSchema.toJson should include empty plain_pass placeholder',
        () {
      final schema = AccountSchema(
        uuid: 'test-uuid',
        accountName: 'Test',
        displayName: 'Test',
        server: 'sip.example.com',
        username: 'user',
        authUsername: 'user',
        password: 'password123',
      );

      final json = schema.toJson();
      expect(json, containsPair('plain_pass', ''));
    });
  });
}
