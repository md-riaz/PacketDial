abstract class SecureSecretsStore {
  Future<void> writeSipPassword(String accountId, String value);
  Future<String?> readSipPassword(String accountId);
  Future<void> deleteSipPassword(String accountId);
}
