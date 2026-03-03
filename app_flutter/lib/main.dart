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
import 'providers/engine_provider.dart';
import 'screens/accounts_screen.dart';
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
    await windowManager.setIcon('assets/app_icon.png');
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

  static final _screens = [
    const AccountsScreen(),
    const DialerScreen(),
    const HistoryScreen(),
    const DiagnosticsScreen(),
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

      // CRITICAL: Attach first so we don't miss "EngineReady" or early logs
      EngineChannel.instance.attach(engine, widget.isar);

      final rc = engine.init(userAgent);

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
        inputDecorationTheme: const InputDecorationTheme(
          filled: false,
          border: UnderlineInputBorder(),
        ),
      ),
      home: _ready
          ? Scaffold(
              body: Column(
                children: [
                  // Custom Title Bar
                  WindowTitleBarBox(
                    child: Row(
                      children: [
                        const SizedBox(width: 8),
                        Image.asset('assets/app_icon.png',
                            width: 16, height: 16),
                        const SizedBox(width: 8),
                        Text(
                          'PacketDial',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo.shade900,
                          ),
                        ),
                        Expanded(child: MoveWindow()),
                        const WindowButtons(),
                      ],
                    ),
                  ),
                  Expanded(child: _screens[_selectedIndex]),
                  const CockpitFooter(),
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
      mouseOver: Colors.indigo.withValues(alpha: 0.1),
      mouseDown: Colors.indigo.withValues(alpha: 0.2),
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

class CockpitFooter extends ConsumerWidget {
  const CockpitFooter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(activeAccountProvider);
    final regState = ref.watch(registrationStateProvider);
    final activeCall = ref.watch(activeCallProvider);

    bool isRegistered = regState == 'Registered';
    bool isFailed = regState.startsWith('Registration Failed');
    bool hasCall = activeCall != null;

    return Container(
      height: 24,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          // Registration Status
          Icon(
            isRegistered
                ? Icons.check_circle
                : (isFailed ? Icons.error : Icons.radio_button_unchecked),
            size: 12,
            color: isRegistered
                ? Colors.green
                : (isFailed ? Colors.red : Colors.orange),
          ),
          Flexible(
            child: Text(
              account != null ? '${account.username}: $regState' : regState,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: isRegistered
                    ? Colors.green.shade700
                    : (isFailed ? Colors.red.shade700 : Colors.grey.shade700),
              ),
            ),
          ),
          const VerticalDivider(width: 16, indent: 4, endIndent: 4),

          // Network / Call Status
          if (hasCall) ...[
            const Icon(Icons.call, size: 10, color: Colors.blue),
            Flexible(
              child: Text(
                'Call: ${activeCall.state.label} (${activeCall.uri})',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: const TextStyle(
                    fontSize: 10,
                    color: Colors.blue,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ] else ...[
            const Icon(Icons.network_check, size: 10, color: Colors.grey),
            const SizedBox(width: 4),
            const Text('Network: OK',
                style: TextStyle(fontSize: 10, color: Colors.grey)),
          ],

          const Spacer(),

          // App Version
          const Text('v1.0.0',
              style: TextStyle(fontSize: 9, color: Colors.grey)),
        ],
      ),
    );
  }
}

void log(String s) {
  // Simple logger stub
  debugPrint(s);
}
