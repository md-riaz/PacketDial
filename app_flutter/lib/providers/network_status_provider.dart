import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

enum NetworkReachabilityStatus {
  online,
  offline,
}

final networkStatusProvider =
    StreamProvider<NetworkReachabilityStatus>((ref) async* {
  final connection = InternetConnection();
  final controller = StreamController<NetworkReachabilityStatus>();

  Future<void> emitCurrent() async {
    final hasInternet = await connection.hasInternetAccess;
    controller.add(
      hasInternet
          ? NetworkReachabilityStatus.online
          : NetworkReachabilityStatus.offline,
    );
  }

  await emitCurrent();

  final sub = connection.onStatusChange.listen((status) {
    controller.add(
      status == InternetStatus.connected
          ? NetworkReachabilityStatus.online
          : NetworkReachabilityStatus.offline,
    );
  });

  ref.onDispose(() async {
    await sub.cancel();
    await controller.close();
  });

  yield* controller.stream;
});
