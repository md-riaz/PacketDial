import 'package:riverpod/riverpod.dart';

import '../models/diagnostics_bundle.dart';

class DiagnosticsLedger extends StateNotifier<DiagnosticsBundle> {
  DiagnosticsLedger()
    : super(
        const DiagnosticsBundle(
          summary: 'Bridge not initialized yet.',
          facts: <String, String>{},
          logs: <String>[],
        ),
      );

  void replace(DiagnosticsBundle bundle) {
    state = bundle;
  }

  void prependLog(String line) {
    state = DiagnosticsBundle(
      summary: state.summary,
      facts: state.facts,
      logs: <String>[line, ...state.logs].take(30).toList(),
      sections: state.sections,
      lastExportPath: state.lastExportPath,
    );
  }

  void markExportPath(String? path) {
    state = DiagnosticsBundle(
      summary: state.summary,
      facts: state.facts,
      logs: state.logs,
      sections: state.sections,
      lastExportPath: path,
    );
  }

  void updateSummary(String summary) {
    state = DiagnosticsBundle(
      summary: summary,
      facts: state.facts,
      logs: state.logs,
      sections: state.sections,
      lastExportPath: state.lastExportPath,
    );
  }

  void putFact(String key, String value) {
    state = DiagnosticsBundle(
      summary: state.summary,
      facts: <String, String>{...state.facts, key: value},
      logs: state.logs,
      sections: state.sections,
      lastExportPath: state.lastExportPath,
    );
  }

  void putSection(String key, List<String> lines) {
    state = DiagnosticsBundle(
      summary: state.summary,
      facts: state.facts,
      logs: state.logs,
      sections: <String, List<String>>{...state.sections, key: lines},
      lastExportPath: state.lastExportPath,
    );
  }

  void prependSectionLine(String key, String line, {int limit = 8}) {
    final current = state.sections[key] ?? const <String>[];
    putSection(key, <String>[line, ...current].take(limit).toList());
  }

  DiagnosticsBundle get snapshot => state;
}
