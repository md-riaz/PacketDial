/// Severity level of an engine log message.
enum LogLevel {
  error,
  warn,
  info,
  debug;

  static LogLevel fromString(String s) => switch (s) {
        'Error' => LogLevel.error,
        'Warn'  => LogLevel.warn,
        'Debug' => LogLevel.debug,
        _       => LogLevel.info,
      };

  String get label => switch (this) {
        LogLevel.error => 'ERROR',
        LogLevel.warn  => 'WARN',
        LogLevel.info  => 'INFO',
        LogLevel.debug => 'DEBUG',
      };
}

/// A single structured log entry emitted by the Rust engine core.
class LogEntry {
  final LogLevel level;
  final String message;
  final int ts; // Unix timestamp seconds

  const LogEntry({
    required this.level,
    required this.message,
    required this.ts,
  });

  factory LogEntry.fromMap(Map<String, dynamic> m) => LogEntry(
        level:   LogLevel.fromString(m['level'] as String? ?? 'Info'),
        message: m['message'] as String? ?? '',
        ts:      (m['ts'] as num?)?.toInt() ?? 0,
      );
}
