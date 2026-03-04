import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/account_schema.dart';
import '../models/account.dart';
import '../models/call_history_schema.dart';
import '../providers/engine_provider.dart';
import 'package:uuid/uuid.dart';
import 'engine_channel.dart';

/// Result of a trial registration attempt.
class RegistrationResult {
  final bool success;
  final String? errorReason;
  const RegistrationResult({required this.success, this.errorReason});
}

final accountServiceProvider =
    ChangeNotifierProvider((ref) => AccountService(ref));

class AccountService extends ChangeNotifier {
  final Ref _ref;
  Isar? isar;

  AccountService(this._ref);

  /// Attempt a trial SIP registration to validate credentials.
  ///
  /// Registers with a temporary UUID, waits up to [timeout] for a
  /// `RegistrationStateChanged` event, then unregisters the temporary
  /// account regardless of the outcome.
  Future<RegistrationResult> tryRegister({
    required String username,
    required String password,
    required String server,
    String transport = 'udp',
    String domain = '',
    String proxy = '',
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final engine = _ref.read(engineProvider);
    final tempUuid = '_trial_${const Uuid().v4()}';
    final completer = Completer<RegistrationResult>();

    debugPrint('--- [AccountService] Starting trial registration ---');
    debugPrint('Temp UUID: $tempUuid');
    debugPrint('User: $username');
    debugPrint('Server: $server');
    debugPrint('Transport: $transport');
    if (domain.isNotEmpty) debugPrint('Domain: $domain');
    if (proxy.isNotEmpty) debugPrint('Proxy: $proxy');

    StreamSubscription<Map<String, dynamic>>? sub;
    Timer? timer;

    sub = EngineChannel.instance.eventStream.listen((event) {
      if (event['type'] != 'RegistrationStateChanged') return;
      final payload = event['payload'] as Map<String, dynamic>? ?? {};
      final id = payload['account_id'] as String? ?? '';
      if (id != tempUuid) return;

      final stateStr = payload['state'] as String? ?? '';
      final state = RegistrationState.fromString(stateStr);
      final reason = payload['reason'] as String? ?? '';

      debugPrint('[AccountService] Trial Event: $stateStr ($reason)');

      if (state == RegistrationState.registered) {
        if (!completer.isCompleted) {
          debugPrint('[AccountService] Trial Success!');
          completer.complete(const RegistrationResult(success: true));
        }
      } else if (state == RegistrationState.failed) {
        if (!completer.isCompleted) {
          debugPrint('[AccountService] Trial Failed: $reason');
          completer.complete(RegistrationResult(
            success: false,
            errorReason: reason.isNotEmpty ? reason : 'Registration failed',
          ));
        }
      }
    });

    timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        debugPrint(
            '[AccountService] Trial Timed Out after ${timeout.inSeconds}s');
        completer.complete(const RegistrationResult(
          success: false,
          errorReason:
              'Registration timed out. Check server address and network.',
        ));
      }
    });

    try {
      // Use the new flexible JSON-based command to pass ALL parameters
      final payload = {
        'uuid': tempUuid,
        'username': username,
        'password': password,
        'server': server,
        'transport': transport,
        'domain': domain,
        'sip_proxy': proxy,
        // Default other fields for the trial
        'account_name': 'Trial Account',
        'display_name': username,
      };

      final rc = engine.sendCommand('AccountUpsert', jsonEncode(payload));
      debugPrint('[AccountService] AccountUpsert returned rc=$rc');

      if (rc == 0) {
        final regRc = engine.sendCommand(
            'AccountRegister', jsonEncode({'uuid': tempUuid}));
        debugPrint('[AccountService] AccountRegister returned rc=$regRc');
        if (regRc != 0 && !completer.isCompleted) {
          completer.complete(RegistrationResult(
            success: false,
            errorReason: 'Registration command failed (rc=$regRc)',
          ));
        }
      } else if (!completer.isCompleted) {
        completer.complete(RegistrationResult(
          success: false,
          errorReason: 'Account setup failed (rc=$rc)',
        ));
      }
    } catch (e) {
      debugPrint('[AccountService] engine.register exception: $e');
      if (!completer.isCompleted) {
        completer.complete(RegistrationResult(
          success: false,
          errorReason: 'Engine exception: $e',
        ));
      }
    }

    final result = await completer.future;

    // Cleanup: cancel the listener and unregister the trial account
    timer.cancel();
    await sub.cancel();
    debugPrint('[AccountService] Cleaning up trial account $tempUuid');
    engine.unregister(tempUuid);

    return result;
  }

  Future<void> init(Isar isar) async {
    this.isar = isar;
  }

  Future<List<AccountSchema>> getAllAccounts() async {
    return isar!.accountSchemas.where().findAll();
  }

  Future<AccountSchema?> getSelectedAccount() async {
    return isar!.accountSchemas.filter().isSelectedEqualTo(true).findFirst();
  }

  Future<AccountSchema?> getAccountByUuid(String uuid) async {
    return isar!.accountSchemas.filter().uuidEqualTo(uuid).findFirst();
  }

  Future<void> setSelectedAccount(String uuid) async {
    await isar!.writeTxn(() async {
      // Unselect all
      final accounts = await isar!.accountSchemas.where().findAll();
      for (final a in accounts) {
        a.isSelected = false;
        await isar!.accountSchemas.put(a);
      }
      // Select the new one
      final selected =
          await isar!.accountSchemas.filter().uuidEqualTo(uuid).findFirst();
      if (selected != null) {
        selected.isSelected = true;
        await isar!.accountSchemas.put(selected);
      }
    });

    // Handle registration change immediately
    final accounts = await getAllAccounts();
    for (final a in accounts) {
      if (a.uuid == uuid) {
        register(a);
      } else {
        unregister(a.uuid);
      }
    }
    notifyListeners();
  }

  Future<void> saveAccount(AccountSchema account) async {
    if (account.uuid.isEmpty) {
      account.uuid = const Uuid().v4();
    }
    await isar!.writeTxn(() async {
      final count = await isar!.accountSchemas.count();
      if (count == 0) {
        account.isSelected = true;
      } else if (account.isSelected == false && account.id == null) {
        // New account, but not the first, ensure isSelected is false
        account.isSelected = false;
      }
      await isar!.accountSchemas.put(account);
    });
    notifyListeners();
  }

  Future<void> deleteAccount(String uuid) async {
    await isar!.writeTxn(() async {
      await isar!.accountSchemas.filter().uuidEqualTo(uuid).deleteAll();
    });
    notifyListeners();
  }

  // Registration bridge
  void register(AccountSchema schema) {
    final engine = _ref.read(engineProvider);

    debugPrint(
        '[AccountService] Registering account ${schema.accountName} (${schema.uuid})');

    final payload = {
      'uuid': schema.uuid,
      'username': schema.username,
      'password': schema.password,
      'server': schema.server,
      'transport': schema.transport,
      'domain': schema.domain,
      'sip_proxy': schema.sipProxy,
      'account_name': schema.accountName,
      'display_name': schema.displayName,
      'auth_username': schema.authUsername,
      'stun_server': schema.stunServer,
      'turn_server': schema.turnServer,
      'tls_enabled': schema.tlsEnabled,
      'srtp_enabled': schema.srtpEnabled,
    };

    engine.sendCommand('AccountUpsert', jsonEncode(payload));
    engine.sendCommand('AccountRegister', jsonEncode({'uuid': schema.uuid}));
  }

  void unregister(String uuid) {
    final engine = _ref.read(engineProvider);
    engine.unregister(uuid);
  }

  Future<void> autoRegisterAll() async {
    final all = await isar!.accountSchemas.where().findAll();
    if (all.isEmpty) return;

    bool didRegister = false;

    // Register all accounts that have autoRegister enabled
    for (final acct in all) {
      if (acct.autoRegister) {
        register(acct);
        didRegister = true;
      }
    }

    // Fallback: if no account had autoRegister, register the selected one
    // or the first account
    if (!didRegister) {
      final selected = all.where((a) => a.isSelected).firstOrNull ?? all.first;
      register(selected);
    }
  }

  // History persistence
  Future<void> saveCallHistory(CallHistorySchema entry) async {
    await isar!.writeTxn(() async {
      await isar!.callHistorySchemas.put(entry);
    });
  }
}
