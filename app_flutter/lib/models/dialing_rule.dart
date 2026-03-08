import 'package:uuid/uuid.dart';

/// Rule for transforming phone numbers before dialing
class DialingRule {
  String id;
  String name;
  String pattern;
  String replacement;
  bool enabled;
  int priority;

  DialingRule({
    String? id,
    required this.name,
    required this.pattern,
    required this.replacement,
    this.enabled = true,
    this.priority = 0,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'pattern': pattern,
      'replacement': replacement,
      'enabled': enabled,
      'priority': priority,
    };
  }

  factory DialingRule.fromJson(Map<String, dynamic> json) {
    return DialingRule(
      id: json['id'] as String? ?? const Uuid().v4(),
      name: json['name'] as String? ?? 'Rule',
      pattern: json['pattern'] as String? ?? '',
      replacement: json['replacement'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
      priority: json['priority'] as int? ?? 0,
    );
  }

  DialingRule copyWith({
    String? id,
    String? name,
    String? pattern,
    String? replacement,
    bool? enabled,
    int? priority,
  }) {
    return DialingRule(
      id: id ?? this.id,
      name: name ?? this.name,
      pattern: pattern ?? this.pattern,
      replacement: replacement ?? this.replacement,
      enabled: enabled ?? this.enabled,
      priority: priority ?? this.priority,
    );
  }

  /// Apply this rule to transform a number
  String? apply(String number) {
    if (!enabled || pattern.isEmpty) return number;
    try {
      final regex = RegExp(pattern);
      if (regex.hasMatch(number)) {
        return number.replaceAll(regex, replacement);
      }
    } catch (e) {
      // Invalid regex, return original
      return number;
    }
    return number;
  }

  @override
  String toString() => 'DialingRule(name: $name, pattern: $pattern, enabled: $enabled)';
}
