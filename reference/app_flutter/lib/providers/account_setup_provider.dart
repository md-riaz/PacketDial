import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/account_service.dart';
import '../models/account_schema.dart';

class AccountSetupState {
  final bool isRegistering;
  final String? registrationError;
  final String transport;
  final bool srtpEnabled;
  final bool publishPresence;

  const AccountSetupState({
    this.isRegistering = false,
    this.registrationError,
    this.transport = 'udp',
    this.srtpEnabled = false,
    this.publishPresence = false,
  });

  AccountSetupState copyWith({
    bool? isRegistering,
    String? registrationError,
    String? transport,
    bool? srtpEnabled,
    bool? publishPresence,
    bool clearError = false,
  }) {
    return AccountSetupState(
      isRegistering: isRegistering ?? this.isRegistering,
      registrationError:
          clearError ? null : (registrationError ?? this.registrationError),
      transport: transport ?? this.transport,
      srtpEnabled: srtpEnabled ?? this.srtpEnabled,
      publishPresence: publishPresence ?? this.publishPresence,
    );
  }
}

class AccountSetupNotifier extends AutoDisposeNotifier<AccountSetupState> {
  @override
  AccountSetupState build() {
    return const AccountSetupState();
  }

  void loadAccount(AccountSchema? existing) {
    if (existing != null) {
      state = state.copyWith(
        transport: existing.transport,
        srtpEnabled: existing.srtpEnabled,
        publishPresence: existing.publishPresence,
      );
    } else {
      state = const AccountSetupState(); // Reset
    }
  }

  void setTransport(String transport) {
    state = state.copyWith(transport: transport);
  }

  void setSrtpEnabled(bool enabled) {
    state = state.copyWith(srtpEnabled: enabled);
  }

  void setPublishPresence(bool enabled) {
    state = state.copyWith(publishPresence: enabled);
  }

  void setRegistering(bool registering) {
    state = state.copyWith(isRegistering: registering);
  }

  void setError(String? error) {
    state = state.copyWith(registrationError: error, clearError: error == null);
  }

  Future<bool> saveAccount({
    required AccountSchema? existing,
    required String name,
    required String displayName,
    required String server,
    required String username,
    required String password,
    required String authUsername,
    required String domain,
    required String proxy,
    required String stunServer,
    required String turnServer,
  }) async {
    if (name.isEmpty ||
        server.isEmpty ||
        username.isEmpty ||
        password.isEmpty) {
      setError('Please fill in all required fields.');
      return false;
    }

    setRegistering(true);
    setError(null);

    try {
      final service = ref.read(accountServiceProvider);

      // Try registering first
      final result = await service.tryRegister(
        username: username,
        password: password,
        server: server,
        transport: state.transport,
        domain: domain,
        proxy: proxy,
        stunServer: stunServer,
        authUsername: authUsername,
      );

      if (!result.success) {
        setRegistering(false);
        setError(result.errorReason ??
            'Registration failed. Check your credentials.');
        return false;
      }

      // Registration succeeded, save the account
      final schema = AccountSchema(
        uuid: existing?.uuid ?? '',
        accountName: name,
        displayName: displayName,
        server: server,
        sipProxy: proxy,
        username: username,
        authUsername: authUsername,
        domain: domain,
        password: password,
        transport: state.transport,
        stunServer: stunServer,
        turnServer: turnServer,
        tlsEnabled: state.transport == 'tls',
        srtpEnabled: state.srtpEnabled,
        publishPresence: state.publishPresence,
        autoRegister: true,
        isSelected: existing?.isSelected ?? false,
      );

      await service.saveAccount(schema);
      final rc = service.register(schema);

      if (rc != 0) {
        setRegistering(false);
        setError('Account saved but registration command failed (rc=$rc).');
        return false;
      }

      return true; // Success
    } catch (e) {
      setRegistering(false);
      setError('Failed to save account: $e');
      return false;
    }
  }
}

final accountSetupProvider =
    AutoDisposeNotifierProvider<AccountSetupNotifier, AccountSetupState>(
  () => AccountSetupNotifier(),
);
