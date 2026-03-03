import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:window_manager/window_manager.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';

import 'core/engine_channel.dart';
import 'ffi/engine.dart';
import 'screens/accounts_screen.dart';
import 'screens/active_call_screen.dart';
import 'screens/diagnostics_screen.dart';
import 'screens/dialer_screen.dart';
import 'screens/history_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Window Manager
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(360, 640),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden, // We use bitsdojo_window for title bar
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(
    const ProviderScope(
      child: App(),
    ),
  );

  // Initialize Bitsdojo Window
  doWhenWindowReady(() {
    const initialSize = Size(360, 640);
    appWindow.minSize = const Size(320, 480);
    appWindow.size = initialSize;
    appWindow.alignment = Alignment.center;
    appWindow.title = "PacketDial";
    appWindow.show();
  });
}

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  int _selectedIndex = 0;
  String _status = 'Initializing…';
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
      final packageInfo = await PackageInfo.fromPlatform();
      final appName = packageInfo.appName;
      final version = packageInfo.version;
      final buildNumber = packageInfo.buildNumber;
      final platform = Platform.operatingSystem;

      final userAgent =
          '$appName/$version ($platform; Flutter; build:$buildNumber)';

      final engine = VoipEngine.load();
      final v = engine.version();
      final rc = engine.init(userAgent);
      EngineChannel.instance.attach(engine);
      setState(() {
        _status = rc == 0 ? 'Engine ready  •  $v' : 'Engine error: $rc';
        _ready = rc == 0;
      });
    } catch (e) {
      log("Failed to load engine: $e");
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
      debugShowCheckedModeBanner: false,
      title: 'PacketDial',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: _ready
          ? Scaffold(
              body: Column(
                children: [
                  // Custom Title Bar
                  WindowTitleBarBox(
                    child: Row(
                      children: [
                        Expanded(child: MoveWindow()),
                        const WindowButtons(),
                      ],
                    ),
                  ),
                  Expanded(child: _screens[_selectedIndex]),
                ],
              ),
              bottomNavigationBar: NavigationBar(
                height: 60,
                selectedIndex: _selectedIndex,
                onDestinationSelected: (i) =>
                    setState(() => _selectedIndex = i),
                destinations: const [
                  NavigationDestination(
                      icon: Icon(Icons.manage_accounts, size: 20),
                      label: 'Accounts'),
                  NavigationDestination(
                      icon: Icon(Icons.dialpad, size: 20), label: 'Dialer'),
                  NavigationDestination(
                      icon: Icon(Icons.call, size: 20), label: 'Call'),
                  NavigationDestination(
                      icon: Icon(Icons.history, size: 20), label: 'History'),
                  NavigationDestination(
                      icon: Icon(Icons.bug_report, size: 20),
                      label: 'Diagnostics'),
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

class WindowButtons extends StatelessWidget {
  const WindowButtons({super.key});

  @override
  Widget build(BuildContext context) {
    final buttonColors = WindowButtonColors(
      iconNormal: Colors.indigo,
      mouseOver: Colors.indigo.withOpacity(0.1),
      mouseDown: Colors.indigo.withOpacity(0.2),
      iconMouseOver: Colors.indigo,
      iconMouseDown: Colors.indigo,
    );

    final closeButtonColors = WindowButtonColors(
      mouseOver: const Color(0xFFD32F2F),
      mouseDown: const Color(0xFFB71C1C),
      iconNormal: Colors.indigo,
      iconMouseOver: Colors.white,
    );

    return Row(
      children: [
        MinimizeWindowButton(colors: buttonColors),
        MaximizeWindowButton(colors: buttonColors),
        CloseWindowButton(
          colors: closeButtonColors,
          onPressed: () {
            // Minimize to tray
            windowManager.hide();
          },
        ),
      ],
    );
  }
}

void log(String s) {
  // Simple logger stub
  debugPrint(s);
}
