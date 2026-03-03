import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/engine_channel.dart';
import '../models/log_entry.dart';

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen>
    with SingleTickerProviderStateMixin {
  final _channel = EngineChannel.instance;
  final _scrollEvent = ScrollController();
  final _scrollLog   = ScrollController();

  late final TabController _tabs;

  static const _levels = ['All', 'Error', 'Warn', 'Info', 'Debug'];
  String _filterLevel = 'All';

  // Active log-level selector for the engine (what it emits)
  static const _engineLevels = ['Error', 'Warn', 'Info', 'Debug'];
  String _engineLevel = 'Info';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _channel.events.listen((_) {
      if (mounted) setState(() {});
      _scrollToBottom(_scrollEvent);
      _scrollToBottom(_scrollLog);
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _scrollEvent.dispose();
    _scrollLog.dispose();
    super.dispose();
  }

  void _scrollToBottom(ScrollController ctrl) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ctrl.hasClients) {
        ctrl.jumpTo(ctrl.position.maxScrollExtent);
      }
    });
  }

  void _exportBundle() =>
      _channel.sendCommand('DiagExportBundle', {'anonymize': true});

  void _copyAllEvents() {
    Clipboard.setData(ClipboardData(text: _channel.eventLog.join('\n')));
    _showSnack('Event log copied to clipboard.');
  }

  void _copyAllLogs() {
    final text = _channel.logBuffer
        .map((e) => '[${e.level.label}] ${e.message}')
        .join('\n');
    Clipboard.setData(ClipboardData(text: text));
    _showSnack('Log buffer copied to clipboard.');
  }

  void _clearEvents() => setState(() => _channel.eventLog.clear());
  void _clearLogs()   => setState(() => _channel.logBuffer.clear());

  void _setEngineLevel(String level) {
    setState(() => _engineLevel = level);
    _channel.setLogLevel(level);
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  List<LogEntry> get _filteredLogs {
    if (_filterLevel == 'All') return _channel.logBuffer;
    final target = LogLevel.fromString(_filterLevel);
    return _channel.logBuffer.where((e) => e.level == target).toList();
  }

  Color _levelColor(LogLevel level) => switch (level) {
        LogLevel.error => Colors.red.shade700,
        LogLevel.warn  => Colors.orange.shade700,
        LogLevel.info  => Colors.blue.shade700,
        LogLevel.debug => Colors.grey.shade600,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostics'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(icon: Icon(Icons.list_alt), text: 'Events'),
            Tab(icon: Icon(Icons.receipt_long), text: 'Logs'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildEventTab(),
          _buildLogTab(),
        ],
      ),
    );
  }

  // ── Event log tab ────────────────────────────────────────────────────────

  Widget _buildEventTab() {
    final log = _channel.eventLog;
    return Column(
      children: [
        Expanded(
          child: log.isEmpty
              ? const Center(child: Text('No events yet.'))
              : ListView.builder(
                  controller: _scrollEvent,
                  padding: const EdgeInsets.all(8),
                  itemCount: log.length,
                  itemBuilder: (_, i) => SelectableText(
                    log[i],
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _exportBundle,
                  icon: const Icon(Icons.download),
                  label: const Text('Export Debug Bundle'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.copy),
                tooltip: 'Copy all',
                onPressed: _copyAllEvents,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Clear',
                onPressed: _clearEvents,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Structured log tab ───────────────────────────────────────────────────

  Widget _buildLogTab() {
    final logs = _filteredLogs;
    return Column(
      children: [
        // Controls row: engine level selector + view filter
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 4),
          child: Row(
            children: [
              const Text('Engine:', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 6),
              DropdownButton<String>(
                value: _engineLevel,
                isDense: true,
                items: _engineLevels
                    .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                    .toList(),
                onChanged: (v) { if (v != null) _setEngineLevel(v); },
              ),
              const SizedBox(width: 16),
              const Text('Show:', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 6),
              DropdownButton<String>(
                value: _filterLevel,
                isDense: true,
                items: _levels
                    .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                    .toList(),
                onChanged: (v) { if (v != null) setState(() => _filterLevel = v); },
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: 'Fetch from engine',
                onPressed: () => _channel.getLogBuffer(),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 20),
                tooltip: 'Copy all',
                onPressed: _copyAllLogs,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                tooltip: 'Clear',
                onPressed: _clearLogs,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: logs.isEmpty
              ? const Center(child: Text('No log entries.'))
              : ListView.builder(
                  controller: _scrollLog,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  itemCount: logs.length,
                  itemBuilder: (_, i) {
                    final e = logs[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 48,
                            child: Text(
                              e.level.label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _levelColor(e.level),
                              ),
                            ),
                          ),
                          Expanded(
                            child: SelectableText(
                              e.message,
                              style: const TextStyle(
                                  fontFamily: 'monospace', fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
