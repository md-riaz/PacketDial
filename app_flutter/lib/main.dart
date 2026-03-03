import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:window_manager/window_manager.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:flutter/services.dart';
import 'dart:io';

import 'core/engine_channel.dart';
import 'core/account_service.dart';
import 'models/account_schema.dart';
import 'models/call_history_schema.dart';
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

  // Initialize Isar
  final dir = await getApplicationSupportDirectory();
  final isar = await Isar.open(
    [AccountSchemaSchema, CallHistorySchemaSchema],
    directory: dir.path,
  );

  final container = ProviderContainer();
  final accountService = container.read(accountServiceProvider);
  await accountService.init(isar);

  // Auto-register accounts
  await accountService.autoRegisterAll();

  // Register Global Hotkey (Alt + D) to dial from clipboard
  HotKey dialHotkey = HotKey(
    key: PhysicalKeyboardKey.keyD,
    modifiers: [HotKeyModifier.alt],
    scope: HotKeyScope.system,
  );
  await hotKeyManager.register(
    dialHotkey,
    keyDownHandler: (hotKey) async {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      final number = clipboardData?.text?.trim() ?? '';
      if (number.isNotEmpty) {
        // Show window and trigger dialer (simplified for now)
        await windowManager.show();
        await windowManager.focus();
        // In a real app, we'd navigate to Dialer and pre-fill or auto-call
        log("Hotkey triggered: Dialing $number from clipboard");
      }
    },
  );

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: App(isar: isar),
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
  final Isar isar;
  const App({super.key, required this.isar});

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

      // Get Isar from Riverpod (initialized in main.dart)
      EngineChannel.instance.attach(engine, widget.isar);
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
