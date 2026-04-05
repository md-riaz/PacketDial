import 'dart:async';

import 'package:app_core/app_core.dart';
import 'package:feature_accounts/feature_accounts.dart';
import 'package:feature_calls/feature_calls.dart';
import 'package:feature_contacts/feature_contacts.dart';
import 'package:feature_diagnostics/feature_diagnostics.dart';
import 'package:feature_history/feature_history.dart';
import 'package:feature_settings/feature_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:platform_services/platform_services.dart';

import '../bootstrap/audio_bootstrap.dart';
import '../bootstrap/notifications_bootstrap.dart';
import '../bootstrap/plugin_bootstrap.dart';
import '../bootstrap/window_bootstrap.dart';
import '../persistence/softphone_persistence.dart';
import '../bootstrap/desktop_shell_coordinator.dart';
import '../routes/app_router.dart';
import '../theme/app_theme.dart';
import 'providers.dart';

class SoftphoneApp extends ConsumerStatefulWidget {
  const SoftphoneApp({super.key});

  @override
  ConsumerState<SoftphoneApp> createState() => _SoftphoneAppState();
}

class _SoftphoneAppState extends ConsumerState<SoftphoneApp> {
  late final GoRouter _router;
  late final ProviderSubscription<SoftphoneState> _persistenceSubscription;
  late final ProviderSubscription<SoftphoneState> _notificationsSubscription;
  late final StreamSubscription<NotificationActionEvent>
  _notificationActionSubscription;
  StreamSubscription<List<String>>? _connectivitySubscription;
  final SoftphonePersistence _persistence = SoftphonePersistence();

  @override
  void initState() {
    super.initState();
    _router = _buildRouter();
    _persistenceSubscription = ref.listenManual<SoftphoneState>(
      softphoneControllerProvider,
      (previous, next) {
        _persistence.save(next);
      },
    );
    _notificationsSubscription = ref.listenManual<SoftphoneState>(
      softphoneControllerProvider,
      (previous, next) {
        _syncIncomingCallNotifications(previous, next);
      },
    );
    Future<void>.microtask(_bootstrapApplication);
    _notificationActionSubscription = ref
        .read(platformServicesProvider)
        .notifications
        .actions
        .listen(_handleNotificationAction);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'PacketDial',
      theme: AppTheme.light(),
      routerConfig: _router,
    );
  }

  Future<void> _restoreAndBootstrap() async {
    final controller = ref.read(softphoneControllerProvider.notifier);
    final restored = await _persistence.load();
    if (restored != null) {
      controller.hydrate(restored);
    }
    await controller.bootstrap();
  }

  Future<void> _bootstrapApplication() async {
    final services = ref.read(platformServicesProvider);
    var permissionsReady = false;
    var notificationsReady = false;
    var audioReady = false;
    var desktopReady = false;

    await WindowBootstrap.maybeInit();
    await PluginBootstrap.initialize(services);
    permissionsReady = true;
    await NotificationsBootstrap.initialize(services.notifications);
    notificationsReady = true;
    await AudioBootstrap.configure(services.audioSession);
    audioReady = true;
    await DesktopShellCoordinator.instance.initialize();
    desktopReady = true;
    final controller = ref.read(softphoneControllerProvider.notifier);
    controller.updateBootstrapStatus(
      permissionsReady: permissionsReady,
      notificationsReady: notificationsReady,
      audioReady: audioReady,
      desktopReady: desktopReady,
    );
    final links = await services.connectivity.currentLinks();
    controller.updateConnectivityStatus(links);
    _connectivitySubscription = services.connectivity.watchLinks().listen(
      controller.updateConnectivityStatus,
    );
    await _restoreAndBootstrap();
  }

  @override
  void dispose() {
    _persistenceSubscription.close();
    _notificationsSubscription.close();
    _notificationActionSubscription.cancel();
    _connectivitySubscription?.cancel();
    DesktopShellCoordinator.instance.dispose();
    super.dispose();
  }

  Future<void> _syncIncomingCallNotifications(
    SoftphoneState? previous,
    SoftphoneState next,
  ) async {
    final notifications = ref.read(platformServicesProvider).notifications;
    final previousCall = previous?.activeCall;
    final nextCall = next.activeCall;

    final becameIncomingRinging =
        nextCall != null &&
        nextCall.direction == CallDirection.incoming &&
        nextCall.state == CallState.ringing &&
        previousCall?.id != nextCall.id;
    if (becameIncomingRinging) {
      await notifications.showIncomingCall(
        id: nextCall.id.hashCode,
        title: nextCall.displayName ?? 'Incoming call',
        body: nextCall.remoteIdentity,
        payload: nextCall.id,
      );
      return;
    }

    final noLongerRinging =
        previousCall != null &&
        previousCall.direction == CallDirection.incoming &&
        previousCall.state == CallState.ringing &&
        nextCall != null &&
        nextCall.id == previousCall.id &&
        nextCall.state != CallState.ringing;
    if (noLongerRinging) {
      await notifications.cancel(previousCall.id.hashCode);
      return;
    }

    final clearedIncoming =
        previousCall != null &&
        previousCall.direction == CallDirection.incoming &&
        (nextCall == null || nextCall.id != previousCall.id);
    if (clearedIncoming) {
      await notifications.cancel(previousCall.id.hashCode);
    }
  }

  void _handleNotificationAction(NotificationActionEvent event) {
    final controller = ref.read(softphoneControllerProvider.notifier);
    switch (event.actionId) {
      case FlutterLocalNotificationsService.answerActionId:
        controller.answerIncoming();
        return;
      case FlutterLocalNotificationsService.rejectActionId:
        controller.rejectIncoming();
        return;
      default:
        if (mounted) {
          context.go(AppSection.calls.path);
        }
        return;
    }
  }
}

GoRouter _buildRouter() {
  return GoRouter(
    routes: [
      ShellRoute(
        builder: (context, state, child) => ShellScaffold(child: child),
        routes: [
          for (final section in AppSection.values)
            GoRoute(
              path: section.path,
              pageBuilder: (context, state) =>
                  NoTransitionPage<void>(child: SectionHost(section: section)),
            ),
        ],
      ),
    ],
  );
}

class ShellScaffold extends StatelessWidget {
  const ShellScaffold({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final current = AppSection.values.firstWhere(
      (section) => section.path == location,
      orElse: () => AppSection.calls,
    );
    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width < 900;
    final isExtendedRail = width > 1100;

    if (isCompact) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('PacketDial'),
          centerTitle: false,
        ),
        body: DecoratedBox(
          decoration: const BoxDecoration(color: Color(0xFFFFFFFF)),
          child: child,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: current.index,
          onDestinationSelected: (index) {
            context.go(AppSection.values[index].path);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dialpad_outlined),
              label: 'Calls',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_circle_outlined),
              label: 'Accounts',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline),
              label: 'Contacts',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_outlined),
              label: 'History',
            ),
            NavigationDestination(
              icon: Icon(Icons.tune_outlined),
              label: 'Settings',
            ),
            NavigationDestination(
              icon: Icon(Icons.monitor_heart_outlined),
              label: 'Diagnostics',
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Container(
        color: const Color(0xFFF2F6FA),
        child: Row(
          children: [
            Container(
              width: isExtendedRail ? 232 : 76,
              decoration: const BoxDecoration(
                color: Color(0xFFEFF4F9),
                border: Border(right: BorderSide(color: Color(0xFFD8E3EC))),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 18),
                  const ListTile(
                    dense: true,
                    leading: Icon(Icons.wifi_calling_3_rounded, color: Color(0xFF1DA8D6), size: 22),
                    title: Text(
                      'PacketDial',
                      style: TextStyle(
                        color: Color(0xFF1F2F3B),
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    subtitle: Text('Softphone', style: TextStyle(color: Color(0xFF6B7F8E), fontSize: 12)),
                  ),
                  const Divider(color: Color(0xFFD8E3EC), height: 16),
                  Expanded(
                    child: NavigationRail(
                      extended: isExtendedRail,
                      selectedIndex: current.index,
                      groupAlignment: -0.95,
                      minWidth: 68,
                      minExtendedWidth: 220,
                      onDestinationSelected: (index) {
                        context.go(AppSection.values[index].path);
                      },
                      labelType: isExtendedRail
                          ? NavigationRailLabelType.none
                          : NavigationRailLabelType.selected,
                      destinations: const [
                        NavigationRailDestination(
                          icon: Icon(Icons.dialpad_outlined),
                          label: Text('Calls'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.account_circle_outlined),
                          label: Text('Accounts'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.people_outline),
                          label: Text('Contacts'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.history_outlined),
                          label: Text('History'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.tune_outlined),
                          label: Text('Settings'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.monitor_heart_outlined),
                          label: Text('Diagnostics'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: Color(0xFFFFFFFF),
                  border: Border(
                    left: BorderSide(color: Color(0xFFD8E3EC)),
                  ),
                ),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SectionHost extends ConsumerWidget {
  const SectionHost({super.key, required this.section});

  final AppSection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(softphoneControllerProvider);
    final controller = ref.read(softphoneControllerProvider.notifier);
    final bridge = ref.watch(voipBridgeProvider);

    return switch (section) {
      AppSection.calls => CallsPage(
        accounts: state.accounts,
        selectedAccountId: state.selectedAccountId,
        dialPadText: state.dialPadText,
        activeCall: state.activeCall,
        onAccountChanged: controller.selectAccount,
        onDialPadChanged: controller.updateDialPad,
        onPlaceCall: () {
          controller.placeCall();
        },
        onSimulateIncoming: () {
          controller.simulateIncomingCall();
        },
        onAnswer: () {
          controller.answerIncoming();
        },
        onReject: () {
          controller.rejectIncoming();
        },
        onHangup: () {
          controller.hangup();
        },
        onMuteChanged: (value) {
          controller.setMute(value);
        },
        onHoldChanged: (value) {
          controller.setHold(value);
        },
        onRouteChanged: (value) {
          controller.setAudioRoute(value);
        },
        onSendDtmf: (digits) {
          controller.sendDtmf(digits);
        },
        onBlindTransfer: (destination) {
          controller.blindTransfer(destination);
        },
        onBeginAttendedTransfer: (destination) {
          controller.beginAttendedTransfer(destination);
        },
        supportsIncomingSimulation: bridge.supportsIncomingCallSimulation,
      ),
      AppSection.accounts => AccountsPage(
        accounts: state.accounts,
        selectedAccountId: state.selectedAccountId,
        onSelect: controller.selectAccount,
        onToggleRegistration: (id) {
          controller.toggleRegistration(id);
        },
        onCreateAccount: controller.addAccount,
      ),
      AppSection.contacts => ContactsPage(
        contacts: state.contacts,
        onDialContact: (value) {
          controller.updateDialPad(value);
          context.go(AppSection.calls.path);
        },
        onContactsChanged: (contacts) {
          controller.hydrate(
            ref.read(softphoneControllerProvider).copyWith(contacts: contacts),
          );
        },
      ),
      AppSection.history => HistoryPage(entries: state.history),
      AppSection.settings => SettingsPage(
        settings: state.settings,
        onChanged: controller.updateSettings,
      ),
      AppSection.diagnostics => DiagnosticsPage(
        bundle: state.diagnostics,
        logs: state.logs,
        onExport: () async {
          final directory = await getApplicationSupportDirectory();
          await controller.exportDiagnostics(directory.path);
        },
      ),
    };
  }
}
