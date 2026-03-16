import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:window_manager/window_manager.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'dart:io';
import 'core/app_theme.dart';
import 'core/sip_uri_utils.dart';
import 'core/engine_channel.dart';
import 'core/account_service.dart';
import 'core/contacts_service.dart';
import 'core/app_settings_service.dart';
import 'core/window_prefs.dart';
import 'ffi/engine.dart';
import 'providers/engine_provider.dart';
import 'providers/incoming_call_provider.dart';
import 'providers/app_settings_provider.dart';
import 'providers/network_status_provider.dart';
import 'screens/accounts_screen.dart';
import 'screens/contacts_screen.dart';
import 'screens/dialer_screen.dart';
import 'screens/history_screen.dart';
import 'screens/app_settings_page.dart';
import 'screens/incoming_call_banner.dart';
import 'core/cli_service.dart';
import 'core/tray_controller.dart';

const String _startupLaunchArg = '--startup-launch';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize media_kit for audio playback
  MediaKit.ensureInitialized();

  final launchedFromWindowsStartup = args.contains(_startupLaunchArg);

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
    size: AppTheme.defaultWindowSize,
    center: true,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden, // We use bitsdojo_window for title bar
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    // Enforce min size FIRST — before restoring geometry so it's always active
    await windowManager.setMinimumSize(AppTheme.minWindowSize);
    appWindow.minSize = AppTheme.minWindowSize;

    // Now restore saved position/size (clamped to min in restoreGeometry)
    await windowPrefs.restoreGeometry();
    await windowPrefs.applyAlwaysOnTop();
    await windowPrefs.applyResizeLock();
    // Note: windowManager handles size via restoreGeometry,
    // but we set appWindow to be safe for Bitsdojo components.
    appWindow.size = AppTheme.defaultWindowSize;
    appWindow.alignment = Alignment.center;
    appWindow.title = "PacketDial";

    final iconPath = TrayController.instance.getBestIconPath();
    try {
      await windowManager.setIcon(iconPath);
    } catch (e) {
      debugPrint('[APP] Failed to set window icon from $iconPath: $e');
    }

    // Initialize System Tray
    try {
      await TrayController.instance.init();
    } catch (e) {
      debugPrint('[APP] Failed to initialize tray: $e');
    }

    if (launchedFromWindowsStartup) {
      await windowManager.setSkipTaskbar(true);
      await windowManager.hide();
      debugPrint(
          '[APP] Startup launch detected; app initialized hidden to tray');
    } else {
      await windowManager.setSkipTaskbar(false);
      await windowManager.show();
      await windowManager.focus();
    }
  });

  final container = ProviderContainer();
  final accountService = container.read(accountServiceProvider);
  await accountService.init();

  // Pre-process protocol URIs (tel:, sip:, callto:)
  final processedArgs = <String>[
    ...args.where((arg) => arg != _startupLaunchArg),
  ];
  for (int i = 0; i < processedArgs.length; i++) {
    final arg = processedArgs[i];
    if (arg.startsWith('tel:') ||
        arg.startsWith('sip:') ||
        arg.startsWith('callto:')) {
      final number = arg.split(':').last;
      processedArgs[i] = '-call';
      processedArgs.insert(i + 1, number);
      break;
    }
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: App(
        accountService: accountService,
        windowPrefs: windowPrefs,
        launchedFromWindowsStartup: launchedFromWindowsStartup,
        args: processedArgs, // Pass processed args
      ),
    ),
  );
}

class App extends ConsumerStatefulWidget {
  final AccountService accountService;
  final WindowPrefs windowPrefs;
  final bool launchedFromWindowsStartup;
  final List<String> args;
  const App({
    super.key,
    required this.accountService,
    required this.windowPrefs,
    required this.launchedFromWindowsStartup,
    required this.args,
  });

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App>
    with SingleTickerProviderStateMixin, WindowListener {
  static const double _titleBarHeight = 34;
  int _selectedIndex = 0;
  String _status = 'Initializing…';
  bool _ready = false;
  bool _alwaysOnTop = false;
  bool _resizeLocked = true;
  bool _forcedTopMostForIncoming = false;

  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

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
    _resizeLocked = widget.windowPrefs.resizeLocked;
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
      EngineChannel.instance.attach(engine, widget.accountService);

      final rc = engine.init(userAgent);
      // rc == 0 → OK, rc == 1 → AlreadyInitialized (hot restart: DLL still loaded)
      final engineOk = rc == 0 || rc == 1;

      setState(() {
        _status = engineOk ? 'Engine ready  •  $v' : 'Engine error: $rc';
        _ready = engineOk;
      });

      // Auto-register saved accounts AFTER the callback is attached
      if (engineOk) {
        final dndEnabled = AppSettingsService.instance.dndEnabled;
        final dndRc =
            engine.sendCommand('SetGlobalDnd', '{"enabled":$dndEnabled}');
        if (dndRc != 0) {
          debugPrint('[APP] Failed to sync global DND on boot: rc=$dndRc');
        }

        final ecEnabled = AppSettingsService.instance.ecEnabled;
        engine.sendCommand('SetEcEnabled', '{"enabled":$ecEnabled}');

        final micAmpLevel = AppSettingsService.instance.micAmplificationLevel;
        engine.sendCommand('SetMicAmplification', '{"level":$micAmpLevel}');

        await widget.accountService.autoRegisterAll();

        // Listen for registration failures → auto-show edit page
        _regFailureSub = EngineChannel.instance.eventStream.listen((event) {
          unawaited(_handleIncomingWindowBehavior(event));
          if (event['type'] == 'RegistrationStateChanged') {
            final payload = event['payload'] as Map<String, dynamic>? ?? {};
            if (payload['state'] == 'Failed') {
              final accountId = payload['account_id'] as String? ?? '';
              _onRegistrationFailed(accountId);
            }
          }
        });

        // Handle CLI arguments
        CliService.instance.handleArgs(widget.args);
      }
    } catch (e) {
      log("Failed to load engine: $e");
      setState(() {
        _status = 'Failed to load engine: $e';
      });
    }
  }

  StreamSubscription? _regFailureSub;

  Future<void> _handleIncomingWindowBehavior(Map<String, dynamic> event) async {
    final type = event['type'] as String? ?? '';
    if (type != 'CallStateChanged') return;

    final payload = event['payload'] as Map<String, dynamic>? ?? {};
    final direction = (payload['direction'] as String? ?? '').toLowerCase();
    final state = (payload['state'] as String? ?? '').toLowerCase();

    if (direction == 'incoming' && state == 'ringing') {
      final settings = AppSettingsService.instance;
      final suppressForScreenPop = settings.screenPopSuppressWindow &&
          settings.screenPopUrl.trim().isNotEmpty &&
          settings.screenPopEvent == 'ring';
      if (suppressForScreenPop) {
        return;
      }
      _returnToDialerForIncomingCall();
      try {
        await TrayController.instance.showWindow();
        await windowManager.setAlwaysOnTop(true);
        _forcedTopMostForIncoming = true;
      } catch (e) {
        debugPrint('[APP] Failed to raise window for incoming call: $e');
      }
      return;
    }

    if (state == 'incall' || state == 'ended') {
      if (!_forcedTopMostForIncoming) return;
      _forcedTopMostForIncoming = false;
      final restoreAlwaysOnTop = widget.windowPrefs.alwaysOnTop;
      try {
        await windowManager.setAlwaysOnTop(restoreAlwaysOnTop);
        if (mounted) {
          setState(() => _alwaysOnTop = restoreAlwaysOnTop);
        }
      } catch (e) {
        debugPrint('[APP] Failed to restore always-on-top after call: $e');
      }
    }
  }

  void _returnToDialerForIncomingCall() {
    if (!mounted) return;

    final navigator = _navigatorKey.currentState;
    if (navigator != null) {
      navigator.popUntil((route) => route.isFirst);
    }

    if (_selectedIndex != 0) {
      setState(() => _selectedIndex = 0);
    }
  }

  void _onRegistrationFailed(String accountId) async {
    if (!mounted) return;
    // Look up account
    final account = widget.accountService.getAccountByUuid(accountId);
    if (account == null || !mounted) return;

    // Switch to Accounts tab
    setState(() => _selectedIndex = 0);

    // Show edit dialog after frame with a slight delay
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 500));
      final context = _navigatorKey.currentContext;
      if (context == null || !context.mounted) return;
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
    debugPrint('[APP] onWindowClose triggered');
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
    // Hide to tray instead of destroying
    await TrayController.instance.hideToTray();
    debugPrint('[APP] Window hidden to tray from onWindowClose');
  }

  @override
  void onWindowMoved() async {
    await widget.windowPrefs.saveGeometry();
  }

  @override
  void onWindowResized() async {
    final size = await windowManager.getSize();
    final minW = AppTheme.minWindowSize.width;
    final minH = AppTheme.minWindowSize.height;
    // Snap back if the window somehow ends up below the minimum
    if (size.width < minW || size.height < minH) {
      await windowManager.setSize(Size(
        size.width < minW ? minW : size.width,
        size.height < minH ? minH : size.height,
      ));
      return;
    }
    if (!_resizeLocked) {
      await widget.windowPrefs.saveGeometry();
    }
  }

  void _toggleAlwaysOnTop() async {
    final newValue = !_alwaysOnTop;
    await widget.windowPrefs.setAlwaysOnTop(newValue);
    setState(() => _alwaysOnTop = newValue);
  }

  Future<void> _toggleResizeLock() async {
    final newValue = !_resizeLocked;
    await widget.windowPrefs.setResizeLocked(newValue);
    setState(() => _resizeLocked = newValue);
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
    final lightMode = ref.watch(appSettingsProvider).lightModeEnabled;
    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'PacketDial',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: lightMode ? ThemeMode.light : ThemeMode.dark,
      home: _ready ? _buildMainShell() : _buildSplashScreen(),
    );
  }

  // ── Splash / Loading Screen ─────────────────────────────────────────────
  Widget _buildSplashScreen() {
    // Splash always uses dark palette (shown before theme is applied)
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
    final incomingCallInfo = ref.watch(incomingCallProvider);

    return Stack(
      children: [
        Scaffold(
          bottomNavigationBar: _buildNavBar(),
          body: Column(
            children: [
              _buildTitleBar(),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: KeyedSubtree(
                    key: ValueKey<int>(_selectedIndex),
                    child: _buildScreen(_selectedIndex),
                  ),
                ),
              ),
              const CockpitFooter(),
            ],
          ),
        ),
        if (incomingCallInfo != null)
          Positioned(
            left: 0,
            right: 0,
            top: _titleBarHeight,
            bottom: 0,
            child: IncomingCallBanner(
              callInfo: incomingCallInfo,
              onAnswer: () {
                debugPrint('[MAIN] onAnswer clicked');
                try {
                  final rc = EngineChannel.instance.engine.answerCall();
                  debugPrint('[MAIN] answerCall() returned: $rc');
                } catch (e, stack) {
                  debugPrint('[MAIN] ERROR in answerCall: $e\n$stack');
                }
              },
              onReject: () {
                debugPrint('[MAIN] onReject clicked');
                SchedulerBinding.instance.addPostFrameCallback((_) {
                  EngineChannel.instance.engine.hangup();
                  ref.read(incomingCallProvider.notifier).clear();
                });
              },
            ),
          ),
      ],
    );
  }

  Widget _buildScreen(int index) {
    switch (index) {
      case 0:
        return const DialerScreen();
      case 1:
        return const ContactsScreen();
      case 2:
        return const HistoryScreen();
      case 3:
        return const AccountsScreen();
      case 4:
        return const AppSettingsPage();
      default:
        return const DialerScreen();
    }
  }

  Widget _buildTitleBar() {
    final c = context.colors;
    return WindowTitleBarBox(
      child: Container(
        height: _titleBarHeight,
        decoration: BoxDecoration(gradient: c.titleBarGradient),
        child: Row(
          children: [
            // Left side: icon + title — wrapped in MoveWindow so dragging works here too
            Expanded(
              child: MoveWindow(
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: c.primary.withValues(alpha: 0.3),
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
                        color: c.textPrimary.withValues(alpha: 0.9),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
                    color: _alwaysOnTop ? c.primary : c.textTertiary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            // Resize lock toggle
            Tooltip(
              message: _resizeLocked ? 'Unlock window resize' : 'Lock window size',
              child: InkWell(
                onTap: _toggleResizeLock,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    _resizeLocked ? Icons.lock_outline : Icons.lock_open_outlined,
                    size: 14,
                    color: _resizeLocked ? c.primary : c.textTertiary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            // Theme toggle
            Consumer(
              builder: (context, ref, _) {
                final lightMode =
                    ref.watch(appSettingsProvider).lightModeEnabled;
                final tc = context.colors;
                return Tooltip(
                  message: lightMode ? 'Switch to dark mode' : 'Switch to light mode',
                  child: InkWell(
                    onTap: () => ref
                        .read(appSettingsProvider.notifier)
                        .setLightModeEnabled(!lightMode),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        lightMode
                            ? Icons.dark_mode_outlined
                            : Icons.light_mode_outlined,
                        size: 14,
                        color: tc.primary,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 4),
            const WindowButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildNavBar() {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.surfaceVariant,
        border: Border(top: BorderSide(color: c.border.withValues(alpha: 0.3))),
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
    final c = context.colors;
    final buttonColors = WindowButtonColors(
      iconNormal: c.textSecondary,
      mouseOver: c.primary.withValues(alpha: 0.15),
      mouseDown: c.primary.withValues(alpha: 0.25),
      iconMouseOver: c.textPrimary,
      iconMouseDown: c.textPrimary,
    );

    final closeButtonColors = WindowButtonColors(
      mouseOver: const Color(0xFFD32F2F),
      mouseDown: const Color(0xFFB71C1C),
      iconNormal: c.textSecondary,
      iconMouseOver: Colors.white,
    );

    return Row(
      children: [
        MinimizeWindowButton(colors: buttonColors),
        // Custom maximize button via window_manager so resize-lock constraints are respected
        _MaximizeButton(colors: buttonColors),
        CloseWindowButton(
          colors: closeButtonColors,
          onPressed: () {
            windowManager.close();
          },
        ),
      ],
    );
  }
}

class _MaximizeButton extends StatefulWidget {
  final WindowButtonColors colors;
  const _MaximizeButton({required this.colors});

  @override
  State<_MaximizeButton> createState() => _MaximizeButtonState();
}

class _MaximizeButtonState extends State<_MaximizeButton> {
  bool _hovering = false;
  bool _pressing = false;

  @override
  Widget build(BuildContext context) {
    final bg = _pressing
        ? widget.colors.mouseDown
        : _hovering
            ? widget.colors.mouseOver
            : Colors.transparent;
    final iconColor = (_hovering || _pressing)
        ? widget.colors.iconMouseOver
        : widget.colors.iconNormal;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressing = true),
        onTapUp: (_) => setState(() => _pressing = false),
        onTapCancel: () => setState(() => _pressing = false),
        onTap: () async {
          if (await windowManager.isMaximized()) {
            await windowManager.unmaximize();
          } else {
            await windowManager.maximize();
          }
        },
        child: Container(
          width: 46,
          height: 34,
          color: bg,
          child: Icon(Icons.crop_square, size: 10, color: iconColor),
        ),
      ),
    );
  }
}

class CockpitFooter extends ConsumerWidget {
  const CockpitFooter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final summary = ref.watch(registrationSummaryProvider);
    final activeAccount = ref.watch(activeAccountProvider);
    final regState = ref.watch(registrationStateProvider);
    final activeCall = ref.watch(activeCallProvider);
    final networkStatus = ref.watch(networkStatusProvider);

    final bool isMulti = summary.totalEnabled > 1;

    Color statusColor;
    if (summary.totalRegistered > 0) {
      statusColor = AppTheme.callGreen;
    } else if (summary.totalFailed > 0) {
      statusColor = AppTheme.errorRed;
    } else if (summary.totalRegistering > 0) {
      statusColor = AppTheme.warningAmber;
    } else {
      statusColor = c.textTertiary;
    }

    bool hasCall = activeCall != null;
    final isNetworkOnline =
        networkStatus.valueOrNull != NetworkReachabilityStatus.offline;
    final networkColor = isNetworkOnline ? c.textTertiary : AppTheme.errorRed;
    final networkLabel =
        isNetworkOnline ? 'Network: Online' : 'Network: Offline';

    return Container(
      height: 28,
      width: double.infinity,
      decoration: BoxDecoration(
        color: c.surfaceVariant,
        border: Border(
          top: BorderSide(color: c.border.withValues(alpha: 0.3)),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          AppTheme.statusDot(statusColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              (!isMulti && activeAccount != null)
                  ? '${activeAccount.username}: $regState'
                  : regState,
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
            color: c.border.withValues(alpha: 0.4),
          ),

          if (hasCall) ...[
            Icon(Icons.call, size: 10, color: c.accentBright),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                'Call: ${activeCall.state.label} (${SipUriUtils.friendlyName(activeCall.uri)})',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                    fontSize: 10,
                    color: c.accentBright,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ] else ...[
            Icon(Icons.wifi, size: 10, color: networkColor),
            const SizedBox(width: 4),
            Text(
              networkLabel,
              style: TextStyle(fontSize: 10, color: networkColor),
            ),
          ],

          const Spacer(),

          // Global DND Toggle
          Consumer(
            builder: (context, ref, _) {
              final dndEnabled = ref.watch(appSettingsProvider).dndEnabled;
              final dc = context.colors;
              return InkWell(
                onTap: () async {
                  await ref
                      .read(appSettingsProvider.notifier)
                      .setGlobalDndEnabled(!dndEnabled);
                },
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                            : dc.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'GLOBAL DND',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: dndEnabled
                              ? AppTheme.errorRed
                              : dc.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(width: 12),

          Text('v1.0.0',
              style: TextStyle(
                  fontSize: 9,
                  color: c.textTertiary.withValues(alpha: 0.6),
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
