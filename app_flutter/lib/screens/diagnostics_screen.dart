import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_theme.dart';
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
    // This will export logs, events, SIP messages, and system info to a zip file
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
        LogLevel.error => AppTheme.errorRed,
        LogLevel.warn => AppTheme.warningAmber,
        LogLevel.info => AppTheme.primary,
        LogLevel.debug => AppTheme.textTertiary,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostics'),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.list_alt, size: 14),
                  const SizedBox(width: 4),
                  const Text('Events'),
                  if (_channel.eventLog.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    _CountBadge(count: _channel.eventLog.length),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.receipt_long, size: 14),
                  const SizedBox(width: 4),
                  const Text('Logs'),
                  if (_channel.logBuffer.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    _CountBadge(count: _channel.logBuffer.length),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.message, size: 14),
                  const SizedBox(width: 4),
                  const Text('SIP'),
                  if (_channel.sipMessages.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    _CountBadge(count: _channel.sipMessages.length),
                  ],
                ],
              ),
            ),
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
              ? _buildTabEmpty(Icons.list_alt_outlined, 'No events yet',
                  'Events from the SIP engine will appear here')
              : ListView.builder(
                  controller: _scrollEvent,
                  padding: const EdgeInsets.all(8),
                  itemCount: log.length,
                  itemBuilder: (_, i) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    margin: const EdgeInsets.only(bottom: 2),
                    decoration: BoxDecoration(
                      color: i.isEven
                          ? AppTheme.surfaceCard.withValues(alpha: 0.4)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: SelectableText(
                      log[i],
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
        ),
        _buildTabActions(
          onExport: _exportBundle,
          onCopy: _copyAllEvents,
          onClear: _clearEvents,
          showExport: true,
        ),
      ],
    );
  }

  // ── Structured log tab ───────────────────────────────────────────────────

  Widget _buildLogTab() {
    final logs = _filteredLogs;
    return Column(
      children: [
        // Controls row
        Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 4, 6),
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard.withValues(alpha: 0.3),
            border: Border(
              bottom: BorderSide(color: AppTheme.border.withValues(alpha: 0.3)),
            ),
          ),
          child: Row(
            children: [
              _FilterChip(
                label: 'Engine',
                value: _engineLevel,
                options: _engineLevels,
                onChanged: _setEngineLevel,
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Show',
                value: _filterLevel,
                options: _levels,
                onChanged: (v) => setState(() => _filterLevel = v),
              ),
              const Spacer(),
              _MiniIconButton(
                icon: Icons.refresh,
                tooltip: 'Fetch from engine',
                onPressed: () => _channel.getLogBuffer(),
              ),
              _MiniIconButton(
                icon: Icons.copy,
                tooltip: 'Copy all',
                onPressed: _copyAllLogs,
              ),
              _MiniIconButton(
                icon: Icons.delete_outline,
                tooltip: 'Clear',
                onPressed: _clearLogs,
              ),
            ],
          ),
        ),
        Expanded(
          child: logs.isEmpty
              ? _buildTabEmpty(Icons.receipt_long_outlined, 'No log entries',
                  'Engine logs will stream here in real time')
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
                          // Level badge
                          Container(
                            width: 42,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 2),
                            margin: const EdgeInsets.only(right: 8, top: 1),
                            decoration: BoxDecoration(
                              color:
                                  _levelColor(e.level).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              e.level.label.toUpperCase(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: _levelColor(e.level),
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          Expanded(
                            child: SelectableText(
                              e.message,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                color: AppTheme.textSecondary,
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
        Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 4, 6),
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard.withValues(alpha: 0.3),
            border: Border(
              bottom: BorderSide(color: AppTheme.border.withValues(alpha: 0.3)),
            ),
          ),
          child: Row(
            children: [
              Text(
                '${messages.length} message${messages.length == 1 ? '' : 's'}',
                style:
                    const TextStyle(fontSize: 11, color: AppTheme.textTertiary),
              ),
              const Spacer(),
              _MiniIconButton(
                icon: Icons.copy,
                tooltip: 'Copy all',
                onPressed: _copyAllSipMessages,
              ),
              _MiniIconButton(
                icon: Icons.delete_outline,
                tooltip: 'Clear',
                onPressed: _clearSipMessages,
              ),
            ],
          ),
        ),
        Expanded(
          child: messages.isEmpty
              ? _buildTabEmpty(
                  Icons.message_outlined,
                  'No SIP messages captured yet',
                  'Register an account or make a call to\nsee SIP message traffic here')
              : ListView.builder(
                  controller: _scrollSip,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  itemCount: messages.length,
                  itemBuilder: (_, i) {
                    final m = messages[i];
                    final isSend = m.isSend;
                    final accentColor =
                        isSend ? AppTheme.primary : AppTheme.callGreen;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceCard,
                        borderRadius: BorderRadius.circular(8),
                        border: Border(
                          left: BorderSide(
                            color: accentColor,
                            width: 3,
                          ),
                        ),
                      ),
                      child: ExpansionTile(
                        dense: true,
                        tilePadding: const EdgeInsets.symmetric(horizontal: 10),
                        childrenPadding:
                            const EdgeInsets.fromLTRB(10, 0, 10, 10),
                        iconColor: AppTheme.textTertiary,
                        collapsedIconColor: AppTheme.textTertiary,
                        leading: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isSend ? 'TX' : 'RX',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: accentColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        title: Text(
                          m.firstLine,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${isSend ? "Sent" : "Received"} at ${_formatTime(m.timestamp)}',
                          style: TextStyle(
                            fontSize: 9,
                            color: AppTheme.textTertiary.withValues(alpha: 0.6),
                          ),
                        ),
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color:
                                      AppTheme.border.withValues(alpha: 0.3)),
                            ),
                            child: SelectableText(
                              m.raw,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 10,
                                height: 1.5,
                                color: AppTheme.textSecondary,
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

  // ── Shared helpers ────────────────────────────────────────────────────────

  Widget _buildTabEmpty(IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primary.withValues(alpha: 0.05),
            ),
            child: Icon(icon,
                size: 40, color: AppTheme.textTertiary.withValues(alpha: 0.4)),
          ),
          const SizedBox(height: 12),
          Text(title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary)),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 11,
                color: AppTheme.textTertiary.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }

  Widget _buildTabActions({
    VoidCallback? onExport,
    required VoidCallback onCopy,
    required VoidCallback onClear,
    bool showExport = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard.withValues(alpha: 0.3),
        border: Border(
          top: BorderSide(color: AppTheme.border.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          if (showExport && onExport != null)
            Expanded(
              child: Container(
                height: 36,
                decoration: BoxDecoration(
                  gradient: AppTheme.accentGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onExport,
                    borderRadius: BorderRadius.circular(8),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.download, size: 16, color: Colors.white),
                        SizedBox(width: 6),
                        Text('Export Debug Bundle',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (showExport) const SizedBox(width: 8),
          _MiniIconButton(
            icon: Icons.copy,
            tooltip: 'Copy all',
            onPressed: onCopy,
          ),
          _MiniIconButton(
            icon: Icons.delete_outline,
            tooltip: 'Clear',
            onPressed: onClear,
          ),
        ],
      ),
    );
  }
}

// ── Reusable Widgets ────────────────────────────────────────────────────────

class _CountBadge extends StatelessWidget {
  final int count;
  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: AppTheme.primary,
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;
  const _FilterChip({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 10, color: AppTheme.textTertiary)),
        const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppTheme.border.withValues(alpha: 0.4)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isDense: true,
              style: const TextStyle(fontSize: 11, color: AppTheme.primary),
              dropdownColor: AppTheme.surfaceVariant,
              items: options
                  .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                  .toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  const _MiniIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 16),
      visualDensity: VisualDensity.compact,
      tooltip: tooltip,
      onPressed: onPressed,
      color: AppTheme.textTertiary,
      hoverColor: AppTheme.primary.withValues(alpha: 0.1),
    );
  }
}
