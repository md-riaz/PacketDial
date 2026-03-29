import 'enums.dart';

class ActiveCall {
  const ActiveCall({
    required this.id,
    required this.accountId,
    required this.remoteIdentity,
    required this.direction,
    required this.state,
    required this.startedAt,
    this.displayName,
    this.muted = false,
    this.onHold = false,
    this.route = AudioRoute.earpiece,
  });

  final String id;
  final String accountId;
  final String remoteIdentity;
  final String? displayName;
  final CallDirection direction;
  final CallState state;
  final bool muted;
  final bool onHold;
  final AudioRoute route;
  final DateTime startedAt;

  ActiveCall copyWith({
    String? id,
    String? accountId,
    String? remoteIdentity,
    String? displayName,
    CallDirection? direction,
    CallState? state,
    bool? muted,
    bool? onHold,
    AudioRoute? route,
    DateTime? startedAt,
  }) {
    return ActiveCall(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      remoteIdentity: remoteIdentity ?? this.remoteIdentity,
      displayName: displayName ?? this.displayName,
      direction: direction ?? this.direction,
      state: state ?? this.state,
      muted: muted ?? this.muted,
      onHold: onHold ?? this.onHold,
      route: route ?? this.route,
      startedAt: startedAt ?? this.startedAt,
    );
  }
}
