import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/engine_channel.dart';
import '../models/log_entry.dart';
import '../models/sip_message.dart';

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen>
    with SingleTickerProviderStateMixin {
  final _channel = EngineChannel.instance;
  final _scrollEvent = ScrollController();
  final _scrollLog = ScrollController();
  final _scrollSip = ScrollController();

  late final TabController _tabs;

  static const _levels = ['All', 'Error', 'Warn', 'Info', 'Debug'];
  String _filterLevel = 'All';

  // Active log-level selector for the engine (what it emits)
  static const _engineLevels = ['Error', 'Warn', 'Info', 'Debug'];
  String _engineLevel = 'Info';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _channel.events.listen((_) {
      if (mounted) setState(() {});
      _scrollToBottom(_scrollEvent);
      _scrollToBottom(_scrollLog);
      _scrollToBottom(_scrollSip);
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _scrollEvent.dispose();
    _scrollLog.dispose();
    _scrollSip.dispose();
    super.dispose();
  }

  void _scrollToBottom(ScrollController ctrl) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ctrl.hasClients) {
        ctrl.jumpTo(ctrl.position.maxScrollExtent);
      }
    });
  }

  void _exportBundle() {
    // TODO: Implement with new C ABI - needs engine_export_diagnostics() function
    _showSnack('Export bundle feature coming soon');
  }

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

  void _copyAllSipMessages() {
    final text = _channel.sipMessages
        .map((m) => '[${m.isSend ? "SEND" : "RECV"}] ${m.raw}')
        .join('\n---\n');
    Clipboard.setData(ClipboardData(text: text));
    _showSnack('SIP messages copied to clipboard.');
  }

  void _clearEvents() => setState(() => _channel.eventLog.clear());
  void _clearLogs() => setState(() => _channel.logBuffer.clear());
  void _clearSipMessages() => setState(() => _channel.sipMessages.clear());

  void _setEngineLevel(String level) {
    setState(() => _engineLevel = level);
    _channel.setLogLevel(level);
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  List<LogEntry> get _filteredLogs {
    if (_filterLevel == 'All') return _channel.logBuffer;
    final target = LogLevel.fromString(_filterLevel);
    return _channel.logBuffer.where((e) => e.level == target).toList();
  }

  Color _levelColor(LogLevel level) => switch (level) {
        LogLevel.error => Colors.red.shade700,
        LogLevel.warn => Colors.orange.shade700,
        LogLevel.info => Colors.blue.shade700,
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
            Tab(icon: Icon(Icons.message), text: 'SIP Messages'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildEventTab(),
          _buildLogTab(),
          _buildSipTab(),
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
                    style:
                        const TextStyle(fontFamily: 'monospace', fontSize: 12),
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
          padding: const EdgeInsets.fromLTRB(8, 8, 0, 4),
          child: Row(
            children: [
              const Text('Engine:', style: TextStyle(fontSize: 11)),
              const SizedBox(width: 4),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _engineLevel,
                  isDense: true,
                  style: const TextStyle(fontSize: 12, color: Colors.indigo),
                  items: _engineLevels
                      .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) _setEngineLevel(v);
                  },
                ),
              ),
              const SizedBox(width: 8),
              const Text('Show:', style: TextStyle(fontSize: 11)),
              const SizedBox(width: 4),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _filterLevel,
                  isDense: true,
                  style: const TextStyle(fontSize: 12, color: Colors.indigo),
                  items: _levels
                      .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _filterLevel = v);
                  },
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, size: 18),
                visualDensity: VisualDensity.compact,
                tooltip: 'Fetch from engine',
                onPressed: () => _channel.getLogBuffer(),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 18),
                visualDensity: VisualDensity.compact,
                tooltip: 'Copy all',
                onPressed: _copyAllLogs,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                visualDensity: VisualDensity.compact,
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

  // ── SIP Messages tab ──────────────────────────────────────────────────────

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}';
  }

  Widget _buildSipTab() {
    final messages = _channel.sipMessages;
    return Column(
      children: [
        // Controls row
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 0, 4),
          child: Row(
            children: [
              Text(
                '${messages.length} message${messages.length == 1 ? '' : 's'}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.copy, size: 18),
                visualDensity: VisualDensity.compact,
                tooltip: 'Copy all',
                onPressed: _copyAllSipMessages,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                visualDensity: VisualDensity.compact,
                tooltip: 'Clear',
                onPressed: _clearSipMessages,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: messages.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.message_outlined,
                          size: 48, color: Colors.grey),
                      SizedBox(height: 12),
                      Text('No SIP messages captured yet.',
                          style: TextStyle(color: Colors.grey)),
                      SizedBox(height: 4),
                      Text(
                        'Register an account or make a call to see\nSIP message traffic here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _scrollSip,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  itemCount: messages.length,
                  itemBuilder: (_, i) {
                    final m = messages[i];
                    final arrow = m.isSend ? '→' : '←';
                    final arrowColor =
                        m.isSend ? Colors.blue.shade700 : Colors.green.shade700;
                    final bgColor = m.isSend
                        ? Colors.blue.withValues(alpha: 0.03)
                        : Colors.green.withValues(alpha: 0.03);

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          vertical: 2, horizontal: 2),
                      elevation: 0,
                      color: bgColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                        side: BorderSide(
                          color: arrowColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: ExpansionTile(
                        dense: true,
                        tilePadding: const EdgeInsets.symmetric(horizontal: 8),
                        childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                        leading: Text(
                          arrow,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: arrowColor,
                          ),
                        ),
                        title: Text(
                          m.firstLine,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${m.isSend ? "Sent" : "Received"} at ${_formatTime(m.timestamp)}',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: SelectableText(
                              m.raw,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 10,
                                height: 1.4,
                              ),
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
