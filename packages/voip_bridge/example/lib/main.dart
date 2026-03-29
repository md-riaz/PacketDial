import 'dart:async';

import 'package:flutter/material.dart';
import 'package:voip_bridge/voip_bridge.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final VoipBridge _bridge;
  final List<String> _events = <String>[];
  StreamSubscription<VoipEvent>? _subscription;
  String? _startupError;

  @override
  void initState() {
    super.initState();
    try {
      _bridge = ReferenceEngineVoipBridge.createPreferred();
    } catch (error) {
      _startupError = '$error';
      return;
    }
    _subscription = _bridge.events.listen((event) {
      setState(() {
        _events.insert(0, event.runtimeType.toString());
      });
    });
    Future<void>.microtask(() async {
      await _bridge.initialize(
        const VoipInitConfig(appName: 'PacketDial Example', logLevel: 'debug'),
      );
      await _bridge.registerAccount('demo');
      await _bridge.startCall(accountId: 'demo', destination: '2001');
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('PacketDial Bridge Example')),
        body: _startupError != null
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_startupError!),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: _events.map((event) => Text(event)).toList(),
              ),
      ),
    );
  }
}
