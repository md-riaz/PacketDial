/// Represents a system audio device.
class AudioDevice {
  final int id;
  final String name;
  final String kind; // "Input" or "Output"

  const AudioDevice({required this.id, required this.name, required this.kind});

  factory AudioDevice.fromMap(Map<String, dynamic> m) => AudioDevice(
        id: (m['id'] as num?)?.toInt() ?? 0,
        name: m['name'] as String? ?? '',
        kind: m['kind'] as String? ?? '',
      );

  bool get isInput => kind == 'Input';
  bool get isOutput => kind == 'Output';
}
