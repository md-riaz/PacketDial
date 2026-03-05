enum WindowType {
  incomingCall('incoming_call'),
  accountSetup('account_setup'),
  unknown('unknown');

  final String key;
  const WindowType(this.key);

  static WindowType fromString(String key) {
    return WindowType.values.firstWhere(
      (type) => type.key == key,
      orElse: () => WindowType.unknown,
    );
  }
}
