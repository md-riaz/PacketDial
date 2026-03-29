import 'package:connectivity_plus/connectivity_plus.dart';

import '../interfaces/connectivity_service.dart';

class ConnectivityPlusService implements ConnectivityService {
  ConnectivityPlusService({required ConnectivityService fallback})
    : _fallback = fallback;

  final ConnectivityService _fallback;
  final Connectivity _connectivity = Connectivity();

  @override
  Future<List<String>> currentLinks() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result.map((item) => item.name).toList();
    } catch (_) {
      return _fallback.currentLinks();
    }
  }

  @override
  Stream<List<String>> watchLinks() async* {
    try {
      await for (final result in _connectivity.onConnectivityChanged) {
        yield result.map((item) => item.name).toList();
      }
    } catch (_) {
      yield* _fallback.watchLinks();
    }
  }
}
