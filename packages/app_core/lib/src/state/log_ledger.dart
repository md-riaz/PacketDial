import 'package:riverpod/riverpod.dart';

class LogLedger extends StateNotifier<List<String>> {
  LogLedger() : super(const <String>[]);

  void prepend(String line) {
    state = <String>[line, ...state].take(20).toList();
  }

  void replace(List<String> logs) {
    state = List<String>.unmodifiable(logs);
  }

  List<String> get snapshot => state;
}
