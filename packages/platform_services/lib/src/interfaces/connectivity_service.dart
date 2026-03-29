abstract class ConnectivityService {
  Stream<List<String>> watchLinks();
  Future<List<String>> currentLinks();
}
