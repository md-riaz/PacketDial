import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:window_manager/window_manager.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:flutter/services.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'dart:io';
import 'dart:async';
import 'core/app_theme.dart';
import 'core/sip_uri_utils.dart';
import 'core/engine_channel.dart';
import 'core/account_service.dart';
import 'core/contacts_service.dart';
import 'core/app_settings_service.dart';
import 'core/multi_window/controllers/incoming_call_controller.dart';
import 'core/window_prefs.dart';
import 'models/account_schema.dart';
import 'models/call_history_schema.dart';
import 'ffi/engine.dart';
import 'providers/engine_provider.dart';
import 'screens/accounts_screen.dart';
import 'screens/contacts_screen.dart';
import 'screens/diagnostics_screen.dart';
import 'screens/dialer_screen.dart';
import 'screens/history_screen.dart';
import 'screens/app_settings_page.dart';
import 'core/multi_window/window_router.dart';
import 'core/multi_window/window_type.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Global Error Handler ────────────────────────────────────────────────
  // Capture and log all uncaught Flutter errors
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('[FLUTTER ERROR] ${details.exception}');
    debugPrint('[FLUTTER ERROR STACK] ${details.stack}');
    // In release mode, you might want to send this to a crash reporting service
  };

  // Capture all uncaught Dart isolate errors
  ui.PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[ISOLATE ERROR] $error');
    debugPrint('[ISOLATE ERROR STACK] $stack');
    return true; // Continue execution (don't crash)
  };
  // ────────────────────────────────────────────────────────────────────────

  // ── Multi-window routing ────────────────────────────────────────────────
  // If launched as a sub-window, route to the appropriate popup.
  final windowController = await WindowController.fromCurrentEngine();
  final windowArgs = windowController.arguments;

  final subWindowApp = WindowRouter.getAppForArgs(windowArgs, windowController);
  if (subWindowApp != null) {
    if (windowArgs.startsWith('${WindowType.incomingCall.key}|')) {
      doWhenWindowReady(() {
        appWindow.minSize = const Size(320, 240);
        appWindow.size = const Size(320, 240);
        appWindow.alignment = Alignment.center;
        // bitsdojo_window doesn't have a direct "always on top" yet in some versions,
        // but it handles showing/positioning fine.
        // If always-on-top is critical, we use native FFI later.
        appWindow.show();
      });
    }
    runApp(subWindowApp);
    return;
  }
  // ── Main window continues below ────────────────────────────────────────

  // Initialize Window Manager
  await windowManager.ensureInitialized();

  // Initialize window preferences (position, always-on-top)
  final windowPrefs = WindowPrefs();
  await windowPrefs.init();

  // Initialize app settings service
  await AppSettingsService.instance.loadSettings();

  // Initialize BLF contacts service
  await ContactsService.instance.loadContacts();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(360, 760),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden, // We use bitsdojo_window for title bar
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    // Restore saved position/size before showing
    await windowPrefs.restoreGeometry();
    await windowPrefs.applyAlwaysOnTop();
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
      child: App(
        isar: isar,
        accountService: accountService,
        windowPrefs: windowPrefs,
      ),
    ),
  );

  // Initialize Bitsdojo Window
  doWhenWindowReady(() {
    const initialSize = Size(360, 760);
    appWindow.minSize = const Size(320, 700);
    appWindow.size = initialSize;
    appWindow.alignment = Alignment.center;
    appWindow.title = "PacketDial";
    appWindow.show();
  });
}

class App extends StatefulWidget {
  final Isar isar;
  final AccountService accountService;
  final WindowPrefs windowPrefs;
  const App({
    super.key,
    required this.isar,
    required this.accountService,
    required this.windowPrefs,
  });

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App>
    with SingleTickerProviderStateMixin, WindowListener {
  int _selectedIndex = 0;
  String _status = 'Initializing…';
  bool _ready = false;
  bool _alwaysOnTop = false;

  static final _screens = [
    const DialerScreen(),
    const ContactsScreen(),
    const HistoryScreen(),
    const AccountsScreen(),
    const AppSettingsPage(),
  ];

  late final AnimationController _splashCtrl;
  late final Animation<double> _splashFade;
  late final Animation<double> _splashScale;

  @override
  void initState() {
    super.initState();
    _splashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _splashFade = CurvedAnimation(parent: _splashCtrl, curve: Curves.easeOut);
    _splashScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _splashCtrl, curve: Curves.elasticOut),
    );
    _splashCtrl.forward();
    _alwaysOnTop = widget.windowPrefs.alwaysOnTop;
    windowManager.addListener(this);
    // Prevent default close — we handle it in onWindowClose
    windowManager.setPreventClose(true);
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
      // rc == 0 → OK, rc == 1 → AlreadyInitialized (hot restart: DLL still loaded)
      final engineOk = rc == 0 || rc == 1;

      setState(() {
        _status = engineOk ? 'Engine ready  •  $v' : 'Engine error: $rc';
        _ready = engineOk;
      });

      // Auto-register saved accounts AFTER the callback is attached
      if (engineOk) {
        await widget.accountService.autoRegisterAll();

        // Initialize incoming call popup controller
        IncomingCallController.instance.init();

        // Listen for registration failures → auto-show edit dialog
        _regFailureSub = EngineChannel.instance.eventStream.listen((event) {
          if (event['type'] == 'RegistrationStateChanged') {
            final payload = event['payload'] as Map<String, dynamic>? ?? {};
            if (payload['state'] == 'Failed') {
              final accountId = payload['account_id'] as String? ?? '';
              _onRegistrationFailed(accountId);
            }
          }
        });
      }
    } catch (e) {
      log("Failed to load engine: $e");
      setState(() {
        _status = 'Failed to load engine: $e';
      });
    }
  }

  StreamSubscription? _regFailureSub;

  void _onRegistrationFailed(String accountId) async {
    if (!mounted) return;
    // Look up account from Isar
    final account = await widget.accountService.getAccountByUuid(accountId);
    if (account == null || !mounted) return;

    // Switch to Accounts tab
    setState(() => _selectedIndex = 0);

    // Show edit dialog after frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Registration Failed'),
          content: Text(
            'Account "${account.accountName}" failed to register.\n'
            'Please check your credentials.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    });

    // Cancel after first failure to avoid spamming
    _regFailureSub?.cancel();
  }

  // ── WindowListener callbacks ──────────────────────────────────────────

  @override
  void onWindowClose() async {
    // Check if there's an active call
    final hasActiveCall = EngineChannel.instance.activeCall != null;
    if (hasActiveCall && mounted) {
      final shouldClose = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Active Call in Progress'),
          content: const Text(
            'You have an active call. Are you sure you want to close PacketDial?\n\n'
            'The call will be disconnected.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.errorRed,
              ),
              child: const Text('Close Anyway'),
            ),
          ],
        ),
      );
      if (shouldClose != true) return;
    }
    // Save window geometry before closing
    await widget.windowPrefs.saveGeometry();
    // Hide immediately so the app feels instant while cleanup happens
    await windowManager.hide();
    await windowManager.destroy();
  }

  @override
  void onWindowMoved() async {
    await widget.windowPrefs.saveGeometry();
  }

  @override
  void onWindowResized() async {
    await widget.windowPrefs.saveGeometry();
  }

  void _toggleAlwaysOnTop() async {
    final newValue = !_alwaysOnTop;
    await widget.windowPrefs.setAlwaysOnTop(newValue);
    setState(() => _alwaysOnTop = newValue);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _regFailureSub?.cancel();
    _splashCtrl.dispose();
    EngineChannel.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PacketDial',
      theme: AppTheme.dark,
      home: _ready ? _buildMainShell() : _buildSplashScreen(),
    );
  }

  // ── Splash / Loading Screen ─────────────────────────────────────────────
  Widget _buildSplashScreen() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D0D1A), Color(0xFF1A1040)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _splashFade,
            child: ScaleTransition(
              scale: _splashScale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // App Icon with glow
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.3),
                          blurRadius: 40,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                    child: Image.asset('assets/app_icon.png',
                        width: 72, height: 72),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'PacketDial',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: AppTheme.textPrimary,
                          letterSpacing: 1.5,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _status,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textTertiary,
                        ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation(
                        AppTheme.primary.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Main App Shell ──────────────────────────────────────────────────────
  Widget _buildMainShell() {
    return Scaffold(
      body: Column(
        children: [
          // Custom Title Bar
          _buildTitleBar(),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _screens[_selectedIndex],
            ),
          ),
          const CockpitFooter(),
        ],
      ),
      bottomNavigationBar: _buildNavBar(),
    );
  }

  Widget _buildTitleBar() {
    return WindowTitleBarBox(
      child: Container(
        decoration: const BoxDecoration(gradient: AppTheme.titleBarGradient),
        child: Row(
          children: [
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Image.asset('assets/app_icon.png', width: 16, height: 16),
            ),
            const SizedBox(width: 8),
            Text(
              'PacketDial',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary.withValues(alpha: 0.9),
                letterSpacing: 0.5,
              ),
            ),
            Expanded(child: MoveWindow()),
            // Always-on-top toggle
            Tooltip(
              message: _alwaysOnTop ? 'Unpin from top' : 'Pin on top',
              child: InkWell(
                onTap: _toggleAlwaysOnTop,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    _alwaysOnTop ? Icons.push_pin : Icons.push_pin_outlined,
                    size: 14,
                    color:
                        _alwaysOnTop ? AppTheme.primary : AppTheme.textTertiary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            const WindowButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        border: Border(
          top: BorderSide(
            color: AppTheme.border.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: NavigationBar(
        height: 64,
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dialpad_outlined),
            selectedIcon: Icon(Icons.dialpad),
            label: 'Dialer',
          ),
          NavigationDestination(
            icon: Icon(Icons.contacts_outlined),
            selectedIcon: Icon(Icons.contacts),
            label: 'Contacts',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.manage_accounts_outlined),
            selectedIcon: Icon(Icons.manage_accounts),
            label: 'Accounts',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class WindowButtons extends StatelessWidget {
  const WindowButtons({super.key});

  @override
  Widget build(BuildContext context) {
    final buttonColors = WindowButtonColors(
      iconNormal: AppTheme.textSecondary,
      mouseOver: AppTheme.primary.withValues(alpha: 0.15),
      mouseDown: AppTheme.primary.withValues(alpha: 0.25),
      iconMouseOver: AppTheme.textPrimary,
      iconMouseDown: AppTheme.textPrimary,
    );

    final closeButtonColors = WindowButtonColors(
      mouseOver: const Color(0xFFD32F2F),
      mouseDown: const Color(0xFFB71C1C),
      iconNormal: AppTheme.textSecondary,
      iconMouseOver: Colors.white,
    );

    return Row(
      children: [
        MinimizeWindowButton(colors: buttonColors),
        MaximizeWindowButton(colors: buttonColors),
        CloseWindowButton(
          colors: closeButtonColors,
          onPressed: () {
            // Trigger the onWindowClose handler (which checks for active calls)
            windowManager.close();
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

    final statusColor = isRegistered
        ? AppTheme.callGreen
        : (isFailed ? AppTheme.errorRed : AppTheme.warningAmber);

    return Container(
      height: 28,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        border: Border(
          top: BorderSide(
            color: AppTheme.border.withValues(alpha: 0.3),
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          // Registration Status with glow dot
          AppTheme.statusDot(statusColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              account != null ? '${account.username}: $regState' : regState,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: statusColor.withValues(alpha: 0.9),
              ),
            ),
          ),
          Container(
            width: 1,
            height: 12,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: AppTheme.border.withValues(alpha: 0.4),
          ),

          // Network / Call Status
          if (hasCall) ...[
            const Icon(Icons.call, size: 10, color: AppTheme.accentBright),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                'Call: ${activeCall.state.label} (${SipUriUtils.friendlyName(activeCall.uri)})',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.accentBright,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ] else ...[
            const Icon(Icons.wifi, size: 10, color: AppTheme.textTertiary),
            const SizedBox(width: 4),
            const Text('Network: OK',
                style: TextStyle(fontSize: 10, color: AppTheme.textTertiary)),
          ],

          const Spacer(),

          // DND Toggle
          Consumer(
            builder: (context, ref, _) {
              final dndEnabled = AppSettingsService.instance.dndEnabled;
              return InkWell(
                onTap: () async {
                  await AppSettingsService.instance.setDndEnabled(!dndEnabled);
                },
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: dndEnabled 
                        ? AppTheme.errorRed.withValues(alpha: 0.2)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: dndEnabled 
                          ? AppTheme.errorRed.withValues(alpha: 0.4)
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.do_not_disturb,
                        size: 12,
                        color: dndEnabled 
                            ? AppTheme.errorRed
                            : AppTheme.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'DND',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: dndEnabled 
                              ? AppTheme.errorRed
                              : AppTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          
          const SizedBox(width: 12),

          // App Version
          Text('v1.0.0',
              style: TextStyle(
                  fontSize: 9,
                  color: AppTheme.textTertiary.withValues(alpha: 0.6),
                  letterSpacing: 0.5)),
        ],
      ),
    );
  }
}

void log(String s) {
  // Simple logger stub
  debugPrint(s);
}
