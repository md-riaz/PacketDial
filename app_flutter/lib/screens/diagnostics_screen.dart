import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/engine_channel.dart';

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  final _channel = EngineChannel.instance;
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _channel.events.listen((_) {
      if (mounted) setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
        }
      });
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _exportBundle() =>
      _channel.sendCommand('DiagExportBundle', {'anonymize': true});

  void _copyAll() {
    final text = _channel.eventLog.join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Copied to clipboard.')));
  }

  void _clear() => setState(() => _channel.eventLog.clear());

  @override
  Widget build(BuildContext context) {
    final log = _channel.eventLog;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostics'),
        actions: [
          IconButton(
              icon: const Icon(Icons.copy),
              tooltip: 'Copy all',
              onPressed: _copyAll),
          IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Clear',
              onPressed: _clear),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: log.isEmpty
                ? const Center(child: Text('No events yet.'))
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(8),
                    itemCount: log.length,
                    itemBuilder: (_, i) => SelectableText(
                      log[i],
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 12),
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
