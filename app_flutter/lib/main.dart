import 'package:flutter/material.dart';
import 'ffi/engine.dart';

void main() {
  runApp(const App());
}

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  String _status = 'Not initialized';
  String _version = 'unknown';
  VoipEngine? _engine;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    try {
      final engine = VoipEngine.load();
      final v = engine.version();
      final rc = engine.init();
      setState(() {
        _engine = engine;
        _version = v;
        _status = rc == 0 ? 'Engine initialized' : 'Engine init error: $rc';
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to load engine: $e';
      });
    }
  }

  @override
  void dispose() {
    try {
      _engine?.shutdown();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VoIP Softphone (Scaffold)',
      home: Scaffold(
        appBar: AppBar(title: const Text('VoIP Softphone (Scaffold)')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Core Version: $_version'),
              const SizedBox(height: 12),
              Text('Status: $_status'),
              const SizedBox(height: 24),
              const Text(
                'Next steps: implement command/event channel, then SIP registration & calling.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
