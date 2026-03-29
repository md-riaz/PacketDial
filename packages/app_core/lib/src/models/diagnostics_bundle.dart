class DiagnosticsBundle {
  const DiagnosticsBundle({
    required this.summary,
    required this.facts,
    required this.logs,
    this.sections = const <String, List<String>>{},
    this.lastExportPath,
  });

  final String summary;
  final Map<String, String> facts;
  final List<String> logs;
  final Map<String, List<String>> sections;
  final String? lastExportPath;
}
