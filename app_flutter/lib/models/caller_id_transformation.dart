import 'dart:convert';
import 'package:uuid/uuid.dart';

/// Rule for transforming caller ID using regular expressions
class CallerIdTransformation {
  String id;
  String name;
  String pattern;
  String replacement;
  bool enabled;
  int priority;

  CallerIdTransformation({
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

  factory CallerIdTransformation.fromJson(Map<String, dynamic> json) {
    return CallerIdTransformation(
      id: json['id'] as String? ?? const Uuid().v4(),
      name: json['name'] as String? ?? 'Transformation',
      pattern: json['pattern'] as String? ?? '',
      replacement: json['replacement'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
      priority: json['priority'] as int? ?? 0,
    );
  }

  CallerIdTransformation copyWith({
    String? id,
    String? name,
    String? pattern,
    String? replacement,
    bool? enabled,
    int? priority,
  }) {
    return CallerIdTransformation(
      id: id ?? this.id,
      name: name ?? this.name,
      pattern: pattern ?? this.pattern,
      replacement: replacement ?? this.replacement,
      enabled: enabled ?? this.enabled,
      priority: priority ?? this.priority,
    );
  }

  /// Apply this transformation to a caller ID
  String? apply(String callerId) {
    if (!enabled || pattern.isEmpty) return callerId;
    try {
      final regex = RegExp(pattern);
      if (regex.hasMatch(callerId)) {
        return callerId.replaceAll(regex, replacement);
      }
    } catch (e) {
      // Invalid regex, return original
      return callerId;
    }
    return callerId;
  }

  @override
  String toString() => 'CallerIdTransformation(name: $name, pattern: $pattern, enabled: $enabled)';
}
