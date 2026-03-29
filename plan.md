Build blueprint

This turns the earlier spec into an implementation-ready blueprint for a single Flutter source tree targeting Android, iOS, and Windows, with FFI-first native integration, Flutter plugins first, and method channels only for OS-owned gaps. Flutter’s current guidance is to use dart:ffi for native code and, since Flutter 3.38, to create native-binding packages with flutter create --template=package_ffi. 


---

1) Final architecture decision

Recommended stack

Flutter for app shell and nearly all product UI

Native VoIP core loaded through FFI

PJSIP/PJSUA2 inside the native core

Rust is optional and should be skipped for this project unless explicitly needed later

Flutter plugins for permissions, storage, notifications, connectivity, audio session, desktop window/tray

Method channels only when a maintained plugin does not cover a needed platform API


Ownership boundary

Flutter owns

navigation

onboarding / provisioning

settings

dialer UI

contacts / favorites

recents / call history

diagnostics UI

rendering current call state


Native core owns

SIP stack lifecycle

registration truth

call truth

media truth

transport setup

codecs / NAT settings

SIP/media error mapping

event emission to Flutter


This keeps the VoIP runtime deterministic and avoids duplicating state across Dart and native.


---

2) Repo layout

softphone/
  pubspec.yaml
  melos.yaml

  apps/
    softphone_app/
      lib/
        main.dart
        bootstrap/
        app/
        routes/
        theme/
      android/
      ios/
      windows/
      test/

  packages/
    app_core/
      lib/
        src/
          models/
          repositories/
          services/
          usecases/
          state/
          utils/

    voip_bridge/
      lib/
        voip_bridge.dart
        src/
          api/
          ffi/
          codecs/
          mappers/
          models/
          streams/
      ffigen.yaml
      test/

    feature_accounts/
      lib/
        src/
          pages/
          widgets/
          controllers/
          forms/

    feature_calls/
      lib/
        src/
          pages/
          widgets/
          controllers/
          state/

    feature_contacts/
      lib/
        src/
          pages/
          widgets/
          controllers/

    feature_history/
      lib/
        src/
          pages/
          widgets/
          controllers/

    feature_settings/
      lib/
        src/
          pages/
          widgets/
          controllers/

    feature_diagnostics/
      lib/
        src/
          pages/
          widgets/
          controllers/

    platform_services/
      lib/
        src/
          permissions/
          notifications/
          storage/
          connectivity/
          audio/
          desktop/

  native/
    voip_core/
      include/
        voip_core.h
      src/
        core/
        accounts/
        calls/
        audio/
        transport/
        diagnostics/
        events/
      third_party/
        pjsip/
      android/
      ios/
      windows/
      CMakeLists.txt

3) Package choices

These are the package choices I would start with, based on current availability and platform support.

Core Flutter dependencies

dependencies:
  flutter:
    sdk: flutter

  # state / utility
  flutter_riverpod: ^2.6.1
  freezed_annotation: ^2.4.4
  json_annotation: ^4.9.0
  equatable: ^2.0.7
  collection: ^1.19.1
  uuid: ^4.5.1
  clock: ^1.1.2

  # plugins first
  permission_handler: ^12.0.1
  path_provider: ^2.1.5
  flutter_secure_storage: ^10.0.0
  connectivity_plus: ^7.0.0
  device_info_plus: ^11.5.0
  package_info_plus: ^8.3.1
  flutter_local_notifications: ^21.0.0
  audio_session: ^0.2.2
  wakelock_plus: ^1.5.1

  # desktop
  window_manager: ^0.5.1
  tray_manager: ^0.5.2

  # optional later
  flutter_callkit_incoming: ^3.0.0

Why these

permission_handler is active and supports Android, iOS, web, and Windows. 

path_provider supports Android, iOS, and Windows, including app documents/support/cache directories. 

flutter_secure_storage is active and supports Android, iOS, and Windows. 

connectivity_plus supports Android, iOS, and Windows, but explicitly warns not to treat network type as proof of internet reachability. 

flutter_local_notifications supports Android, iOS, and Windows and includes notification actions and fullscreen intent support on Android. 

audio_session exposes AVAudioSession on iOS and AudioManager-focused behavior on Android. 

wakelock_plus supports Android, iOS, and Windows. 

window_manager and tray_manager are active desktop plugins for Windows window and tray behavior. 

flutter_callkit_incoming is optional and active for Android/iOS native call UI, but should not become the source of truth for SIP state. 


4) App package roles

apps/softphone_app

Final app target.

assembles all feature packages

bootstraps services

owns app routing, themes, top-level error handling


packages/app_core

Pure Dart, no UI.

models

repositories

use cases

app settings service

sync-safe DTOs

feature flags

app session state


packages/voip_bridge

The only Dart package allowed to speak directly to native VoIP code.

FFI bindings

callback registration

event decoding

command API

isolate-safe stream bridging

error code mapping


packages/platform_services

Wrapper over Flutter plugins.

permission manager

secure storage wrapper

notifications wrapper

connectivity wrapper

audio session wrapper

desktop tray/window wrapper


packages/feature_*

UI packages. Each feature package owns:

pages

widgets

controllers / notifiers

view-specific models



---

5) Native module boundaries

5.1 If using C++ only

Use:

PJSUA2

small exported C ABI wrapper for Flutter FFI


native/voip_core/src/
  exported/
    voip_core_c_api.cpp
  core/
    engine.cpp
    engine_state.cpp
  accounts/
    account_manager.cpp
  calls/
    call_manager.cpp
    transfer_manager.cpp
  audio/
    audio_router.cpp
  transport/
    transport_policy.cpp
  diagnostics/
    logger.cpp
    crash_dump.cpp
  events/
    event_bus.cpp
    event_encoder.cpp

6) FFI bridge contract

6.1 Dart-side public API

packages/voip_bridge/lib/voip_bridge.dart

abstract class VoipBridge {
  Future<void> initialize(VoipInitConfig config);
  Future<void> shutdown();

  Future<void> addOrUpdateAccount(VoipAccount account);
  Future<void> removeAccount(String accountId);
  Future<void> registerAccount(String accountId);
  Future<void> unregisterAccount(String accountId);

  Future<CallStartResult> startCall({
    required String accountId,
    required String destination,
  });

  Future<void> answerCall(String callId);
  Future<void> rejectCall(String callId);
  Future<void> hangupCall(String callId);

  Future<void> setMute(String callId, bool muted);
  Future<void> setHold(String callId, bool onHold);
  Future<void> sendDtmf(String callId, String digits);

  Future<void> blindTransfer(String callId, String destination);
  Future<AttendedTransferSession> beginAttendedTransfer(
    String callId,
    String destination,
  );
  Future<void> completeAttendedTransfer({
    required String originalCallId,
    required String consultCallId,
  });

  Future<void> setAudioRoute(AudioRoute route);
  Future<DiagnosticsBundle> collectDiagnostics();

  Stream<VoipEvent> get events;
}

6.2 Event model

Use a sealed event hierarchy.

sealed class VoipEvent {}

final class EngineReady extends VoipEvent {}
final class AccountRegistrationChanged extends VoipEvent {
  final String accountId;
  final RegistrationState state;
  final String? reason;
}
final class IncomingCallEvent extends VoipEvent {
  final String callId;
  final String accountId;
  final String remoteUri;
  final String? displayName;
}
final class CallStateChanged extends VoipEvent {
  final String callId;
  final CallState state;
}
final class CallMediaChanged extends VoipEvent {
  final String callId;
  final bool audioActive;
}
final class AudioRouteChanged extends VoipEvent {
  final AudioRoute route;
}
final class NativeLogEvent extends VoipEvent {
  final String level;
  final String message;
  final DateTime timestamp;
}

6.3 Native C ABI

Keep it stable and versioned.

int voip_core_init(const char* json_config);
int voip_core_shutdown(void);

int voip_core_set_event_callback(void (*cb)(int event_id, const char* payload));

int voip_account_upsert(const char* json_account);
int voip_account_remove(const char* account_id);
int voip_account_register(const char* account_id);
int voip_account_unregister(const char* account_id);

int voip_call_start(const char* account_id, const char* destination, char* out_call_id, int out_len);
int voip_call_answer(const char* call_id);
int voip_call_reject(const char* call_id);
int voip_call_hangup(const char* call_id);

int voip_call_set_mute(const char* call_id, int muted);
int voip_call_set_hold(const char* call_id, int hold);
int voip_call_send_dtmf(const char* call_id, const char* digits);

int voip_call_transfer_blind(const char* call_id, const char* dest);
int voip_call_transfer_attended_start(const char* call_id, const char* dest, char* out_consult_id, int out_len);
int voip_call_transfer_attended_complete(const char* call_a, const char* call_b);

int voip_audio_set_route(int route);
int voip_diag_export(const char* directory_path);


---

7) Data models

7.1 SIP account

class VoipAccount {
  final String id;
  final String displayName;
  final String username;
  final String authUsername;
  final String passwordRef; // actual secret in secure storage
  final String domain;
  final String registrar;
  final String? outboundProxy;
  final SipTransport transport;
  final bool tlsEnabled;
  final bool iceEnabled;
  final bool srtpEnabled;
  final String? stunServer;
  final String? turnServer;
  final int registerExpiresSeconds;
  final List<String> codecs;
  final DtmfMode dtmfMode;
  final String? voicemailNumber;
}

7.2 Call session

class ActiveCall {
  final String id;
  final String accountId;
  final String remoteUri;
  final String? displayName;
  final CallDirection direction;
  final CallState state;
  final bool muted;
  final bool onHold;
  final AudioRoute route;
  final DateTime startedAt;
}


---

8) State management

Use Riverpod at app level.

Providers

voipBridgeProvider

accountsRepositoryProvider

secureStorageProvider

notificationsServiceProvider

audioSessionServiceProvider

connectivityServiceProvider


Call state

callSessionsProvider

activeCallProvider

dialerControllerProvider

incomingCallControllerProvider


Registration state

registrationStatesProvider


Native events should flow into a single VoipEventRouter, which updates Riverpod notifiers.


---

9) Bootstrap flow

main.dart

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await WindowBootstrap.maybeInit();
  await PluginBootstrap.initialize();
  await AudioBootstrap.configure();
  await NotificationsBootstrap.initialize();

  runApp(const ProviderScope(child: SoftphoneApp()));
}

PluginBootstrap.initialize()

init flutter_local_notifications

init flutter_secure_storage

init package_info_plus

init device_info_plus


AudioBootstrap.configure()

Configure audio_session for voice communication profile on Android/iOS. audio_session is specifically for declaring audio app behavior and handling interruptions with AVAudioSession and Android AudioManager. 


---

10) Platform services layer

10.1 Permissions service

Use permission_handler.

abstract class PermissionsService {
  Future<bool> ensureMicrophone();
  Future<bool> ensureNotificationsIfNeeded();
}

10.2 Secure storage service

Use flutter_secure_storage.

abstract class SecureSecretsStore {
  Future<void> writeSipPassword(String accountId, String value);
  Future<String?> readSipPassword(String accountId);
  Future<void> deleteSipPassword(String accountId);
}

10.3 Connectivity service

Use connectivity_plus, but only as a hint. Its docs explicitly say not to rely on interface type as proof of internet access. 

abstract class NetworkStateService {
  Stream<List<ConnectivityResult>> watchLinks();
  Future<List<ConnectivityResult>> currentLinks();
}

10.4 Notifications service

Use flutter_local_notifications.

abstract class AppNotifications {
  Future<void> showIncomingCall({
    required int id,
    required String title,
    required String body,
    required String payload,
  });

  Future<void> cancel(int id);
}

This package supports Android, iOS, and Windows notifications and notification actions. 

10.5 Desktop shell service

Use window_manager + tray_manager.

abstract class DesktopShellService {
  Future<void> showWindow();
  Future<void> hideWindow();
  Future<void> focusWindow();
  Future<void> enableTray();
}

Both packages currently support Windows desktop behavior. 


---

11) Method channel fallback policy

Use method channels only for these kinds of gaps:

Android

speaker vs earpiece forcing if plugin surface is insufficient

Bluetooth SCO edge control

custom full-screen incoming-call handling beyond notification plugin support


iOS

CallKit-specific hooks if optional plugin is insufficient

finer AVAudioSession routing control


Windows

tray/menu edge behavior not exposed by current plugin

startup / single-instance integration if needed


Do not use method channels for:

registration state machine

call state machine

media session logic

SIP command routing


Those belong in FFI/native core.


---

12) Per-platform implementation notes

Android

Use plugins first:

permission_handler

audio_session

flutter_local_notifications

flutter_secure_storage

connectivity_plus


If later you want a native incoming-call surface while the app is active, consider flutter_callkit_incoming, which supports Android/iOS and exposes incoming/outgoing call UI hooks. 

iOS

Use:

audio_session

permission_handler

flutter_local_notifications

flutter_secure_storage


If later you want optional native call UI, flutter_callkit_incoming is the more recently updated option compared with callkeep. 

Windows

Use:

window_manager

tray_manager

flutter_local_notifications

path_provider

flutter_secure_storage


Windows window/tray support is well-covered by the current desktop plugins above. 


---

13) pubspec.yaml split

App target apps/softphone_app/pubspec.yaml

name: softphone_app
publish_to: none

environment:
  sdk: ^3.6.0

dependencies:
  flutter:
    sdk: flutter

  app_core:
    path: ../../packages/app_core
  voip_bridge:
    path: ../../packages/voip_bridge
  feature_accounts:
    path: ../../packages/feature_accounts
  feature_calls:
    path: ../../packages/feature_calls
  feature_contacts:
    path: ../../packages/feature_contacts
  feature_history:
    path: ../../packages/feature_history
  feature_settings:
    path: ../../packages/feature_settings
  feature_diagnostics:
    path: ../../packages/feature_diagnostics
  platform_services:
    path: ../../packages/platform_services

  flutter_riverpod: ^2.6.1
  go_router: ^14.8.1
  freezed_annotation: ^2.4.4
  json_annotation: ^4.9.0

packages/platform_services/pubspec.yaml

dependencies:
  flutter:
    sdk: flutter
  permission_handler: ^12.0.1
  path_provider: ^2.1.5
  flutter_secure_storage: ^10.0.0
  connectivity_plus: ^7.0.0
  device_info_plus: ^11.5.0
  package_info_plus: ^8.3.1
  flutter_local_notifications: ^21.0.0
  audio_session: ^0.2.2
  wakelock_plus: ^1.5.1
  window_manager: ^0.5.1
  tray_manager: ^0.5.2

packages/voip_bridge/pubspec.yaml

dependencies:
  flutter:
    sdk: flutter
  ffi: ^2.1.3
  meta: ^1.15.0
  freezed_annotation: ^2.4.4
  json_annotation: ^4.9.0

dev_dependencies:
  ffigen: ^16.1.0


---

14) Native build plan

Preferred

Create voip_bridge as an FFI package using the Flutter package_ffi template. That is the recommended Flutter path now. 

Build outputs

Android: libvoip_core.so

iOS: voip_core.framework or static library packaging via CocoaPods/SPM-compatible wrapper

Windows: voip_core.dll


FFI loading

DynamicLibrary _loadVoipLibrary() {
  if (Platform.isAndroid) return DynamicLibrary.open('libvoip_core.so');
  if (Platform.isIOS) return DynamicLibrary.process();
  if (Platform.isWindows) return DynamicLibrary.open('voip_core.dll');
  throw UnsupportedError('Unsupported platform');
}

Flutter’s FFI docs include dynamic library naming guidance and asset consistency guidance across platforms. 


---

15) First implementation milestones

Milestone 1

repo + melos workspace

FFI package created

native core loads on Android/iOS/Windows

initialize() works

event callback wiring works

account add/register/unregister works


Milestone 2

outgoing call

incoming call while active

answer/reject/hangup

mute/hold/DTMF

call state reflected in Flutter


Milestone 3

secure credentials

call history

contacts/favorites

notifications

diagnostics export

desktop tray/window behavior


Milestone 4

transport switching UI

TLS policy

STUN/ICE account settings

transfer flows

basic audio route controls



---

16) What I would code first

1. voip_bridge FFI package scaffold


2. native initialize / shutdown / set_event_callback


3. account register/unregister


4. Flutter AccountsPage + account persistence


5. CallStart + CallStateChanged


6. active call screen


7. notifications + diagnostics




---

17) Strong recommendation

If you want the fastest path with least architectural regret:

use Flutter for everything visible

use FFI for the VoIP engine

keep plugins inside platform_services

keep method channels tiny and rare

keep native call truth out of Dart reducers


That gives you one source tree, maximum reuse, and a clean escape hatch when a plugin is not enough.

