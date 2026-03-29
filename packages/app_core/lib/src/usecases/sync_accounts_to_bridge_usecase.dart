import 'package:platform_services/platform_services.dart';
import 'package:voip_bridge/voip_bridge.dart';

import '../models/sip_account.dart';

class SyncAccountsToBridgeUseCase {
  const SyncAccountsToBridgeUseCase({
    required VoipBridge bridge,
    required SecureSecretsStore secretsStore,
  }) : _bridge = bridge,
       _secretsStore = secretsStore;

  final VoipBridge _bridge;
  final SecureSecretsStore _secretsStore;

  Future<void> execute(List<SipAccount> accounts) async {
    for (final account in accounts) {
      final storedPassword = await _secretsStore.readSipPassword(
        account.passwordRef,
      );
      await _bridge.addOrUpdateAccount(
        VoipAccount(
          id: account.id,
          displayName: account.displayName,
          username: account.username,
          authUsername: account.authUsername,
          domain: account.domain,
          registrar: account.registrar ?? 'sip:${account.domain}',
          transport: account.transport.name,
          outboundProxy: account.outboundProxy,
          tlsEnabled: account.tlsEnabled,
          iceEnabled: account.iceEnabled,
          srtpEnabled: account.srtpEnabled,
          stunServer: account.stunServer,
          turnServer: account.turnServer,
          registerExpiresSeconds: account.registerExpiresSeconds,
          codecs: account.codecs,
          dtmfMode: account.dtmfMode.name,
          voicemailNumber: account.voicemailNumber,
          password: storedPassword,
        ),
      );
    }
  }
}
