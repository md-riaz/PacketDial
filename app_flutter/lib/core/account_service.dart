import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/account_schema.dart';
import '../models/account.dart';
import '../models/call_history_schema.dart';
import '../providers/engine_provider.dart';
import 'engine_channel.dart';
import 'path_provider_service.dart';

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
  List<AccountSchema> _accounts = [];
  List<CallHistorySchema> _history = [];
  bool _isLoaded = false;

  AccountService(this._ref);

  /// Attempt a trial SIP registration to validate credentials.
  Future<RegistrationResult> tryRegister({
    required String username,
    required String password,
    required String server,
    String? transport,
    String? domain,
    String? proxy,
    String? stunServer,
    String? authUsername,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final engine = _ref.read(engineProvider);
    final tempUuid = '_trial_${const Uuid().v4()}';
    final completer = Completer<RegistrationResult>();

    debugPrint('--- [AccountService] Starting trial registration ---');
    debugPrint('Temp UUID: $tempUuid');

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
      final payload = {
        'uuid': tempUuid,
        'username': username,
        'password': password,
        'server': server,
        'transport': transport,
        'domain': domain,
        'sip_proxy': proxy,
        'stun_server': stunServer ?? '',
        'auth_username': authUsername,
        'account_name': 'Trial Account',
        'display_name': username,
      };

      debugPrint(
          '[AccountService] tryRegister payload: ${jsonEncode(payload)}');
      final rc = engine.sendCommand('AccountUpsert', jsonEncode(payload));

      if (rc == 0) {
        final regRc = engine.sendCommand(
            'AccountRegister', jsonEncode({'uuid': tempUuid}));
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

    timer.cancel();
    await sub.cancel();
    debugPrint('[AccountService] Purging trial account $tempUuid');
    engine.deleteAccount(tempUuid);

    return result;
  }

  Future<void> init() async {
    if (_isLoaded) return;
    await loadAccounts();
    await loadHistory();
    _isLoaded = true;
  }

  Future<File> _getAccountsFile() async {
    final dir = await PathProviderService.instance.getDataDirectory();
    return File('${dir.path}/accounts.json');
  }

  Future<File> _getHistoryFile() async {
    final dir = await PathProviderService.instance.getDataDirectory();
    return File('${dir.path}/call_history.json');
  }

  Future<void> loadAccounts() async {
    try {
      final file = await _getAccountsFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(content);
        _accounts = jsonList.map((j) => AccountSchema.fromJson(j)).toList();
      } else {
        _accounts = [];
        await _saveAccounts();
      }
    } catch (e) {
      debugPrint('[AccountService] Error loading accounts: $e');
      _accounts = [];
    }
    notifyListeners();
  }

  Future<void> loadHistory() async {
    try {
      final file = await _getHistoryFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(content);
        _history = jsonList.map((j) => CallHistorySchema.fromJson(j)).toList();
      } else {
        _history = [];
        await _saveHistory();
      }
    } catch (e) {
      debugPrint('[AccountService] Error loading history: $e');
      _history = [];
    }
    notifyListeners();
  }

  Future<void> _saveAccounts() async {
    try {
      final file = await _getAccountsFile();
      await file.writeAsString(
          jsonEncode(_accounts.map((a) => a.toJson()).toList()),
          flush: true);
    } catch (e) {
      debugPrint('[AccountService] Error saving accounts: $e');
    }
  }

  Future<void> _saveHistory() async {
    try {
      final file = await _getHistoryFile();
      await file.writeAsString(
          jsonEncode(_history.map((h) => h.toJson()).toList()),
          flush: true);
    } catch (e) {
      debugPrint('[AccountService] Error saving history: $e');
    }
  }

  List<AccountSchema> getAllAccounts() {
    return _accounts;
  }

  AccountSchema? getSelectedAccount() {
    try {
      return _accounts.firstWhere((a) => a.isSelected);
    } catch (_) {
      return null;
    }
  }

  AccountSchema? getAccountByUuid(String uuid) {
    try {
      return _accounts.firstWhere((a) => a.uuid == uuid);
    } catch (_) {
      return null;
    }
  }

  Future<void> setSelectedAccount(String uuid) async {
    for (final a in _accounts) {
      a.isSelected = (a.uuid == uuid);
    }
    await _saveAccounts();
    notifyListeners();
  }

  Future<void> saveAccount(AccountSchema account) async {
    if (account.uuid.isEmpty) {
      account.uuid = const Uuid().v4();
    }

    final index = _accounts.indexWhere((a) => a.uuid == account.uuid);
    if (index >= 0) {
      _accounts[index] = account;
    } else {
      if (_accounts.isEmpty) {
        account.isSelected = true;
      } else {
        account.isSelected = false;
      }
      _accounts.add(account);
    }
    await _saveAccounts();
    notifyListeners();
  }

  Future<void> deleteAccount(String uuid) async {
    unregister(uuid);
    _ref.read(engineProvider).deleteAccount(uuid);

    final index = _accounts.indexWhere((a) => a.uuid == uuid);
    if (index >= 0) {
      final wasSelected = _accounts[index].isSelected;
      _accounts.removeAt(index);
      if (wasSelected && _accounts.isNotEmpty) {
        _accounts[0].isSelected = true;
      }
      await _saveAccounts();
    }
    notifyListeners();
  }

  Future<void> setAccountEnabled(String uuid, bool enabled) async {
    final account = getAccountByUuid(uuid);
    if (account != null) {
      account.isEnabled = enabled;
      await _saveAccounts();
      notifyListeners();
    }
  }

  // Registration bridge
  int register(AccountSchema schema) {
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

    final safePayload = Map<String, dynamic>.from(payload);
    safePayload['password'] =
        (schema.password.isNotEmpty) ? '***' : schema.password;
    debugPrint(
        '[AccountService] AccountUpsert payload: ${jsonEncode(safePayload)}');

    final upsertRc = engine.sendCommand('AccountUpsert', jsonEncode(payload));
    if (upsertRc != 0) {
      return upsertRc;
    }

    final regRc = engine.sendCommand(
        'AccountRegister', jsonEncode({'uuid': schema.uuid}));
    return regRc;
  }

  int unregister(String uuid) {
    final engine = _ref.read(engineProvider);
    final rc =
        engine.sendCommand('AccountUnregister', jsonEncode({'uuid': uuid}));
    return rc;
  }

  Future<void> autoRegisterAll() async {
    if (_accounts.isEmpty) return;
    for (final acct in _accounts) {
      if (acct.isEnabled) {
        register(acct);
      }
    }
  }

  // History persistence
  List<CallHistorySchema> getHistory() => List.unmodifiable(_history);

  Future<void> saveCallHistory(CallHistorySchema entry) async {
    if (entry.id.isEmpty) {
      entry.id = const Uuid().v4();
    }
    _history.add(entry);
    await _saveHistory();
    notifyListeners();
  }

  Future<void> clearHistory() async {
    _history.clear();
    await _saveHistory();
    notifyListeners();
  }
}
