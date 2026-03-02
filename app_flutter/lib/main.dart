import 'package:flutter/material.dart';

import 'core/engine_channel.dart';
import 'ffi/engine.dart';
import 'screens/accounts_screen.dart';
import 'screens/active_call_screen.dart';
import 'screens/diagnostics_screen.dart';
import 'screens/dialer_screen.dart';
import 'screens/history_screen.dart';

void main() {
  runApp(const App());
}

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  int _selectedIndex = 0;
  String _status = 'Initializing…';
  String _version = '';
  bool _ready = false;

  static const _screens = [
    AccountsScreen(),
    DialerScreen(),
    ActiveCallScreen(),
    HistoryScreen(),
    DiagnosticsScreen(),
  ];

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
      EngineChannel.instance.attach(engine);
      setState(() {
        _version = v;
        _status = rc == 0 ? 'Engine ready  •  $v' : 'Engine error: $rc';
        _ready = rc == 0;
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to load engine: $e';
      });
    }
  }

  @override
  void dispose() {
    EngineChannel.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PacketDial',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: _ready
          ? Scaffold(
              body: _screens[_selectedIndex],
              bottomNavigationBar: NavigationBar(
                selectedIndex: _selectedIndex,
                onDestinationSelected: (i) =>
                    setState(() => _selectedIndex = i),
                destinations: const [
                  NavigationDestination(
                      icon: Icon(Icons.manage_accounts),
                      label: 'Accounts'),
                  NavigationDestination(
                      icon: Icon(Icons.dialpad), label: 'Dialer'),
                  NavigationDestination(
                      icon: Icon(Icons.call), label: 'Call'),
                  NavigationDestination(
                      icon: Icon(Icons.history), label: 'History'),
                  NavigationDestination(
                      icon: Icon(Icons.bug_report), label: 'Diagnostics'),
                ],
              ),
            )
          : Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(_status),
                  ],
                ),
              ),
            ),
    );
  }
}

