import '../models/enums.dart';
import '../models/sip_account.dart';

class AccountRepository {
  const AccountRepository();

  List<SipAccount> ensureSeeded(List<SipAccount> accounts) {
    if (accounts.isNotEmpty) {
      return accounts;
    }

    return const <SipAccount>[
      SipAccount(
        id: 'demo-primary-account',
        label: 'Primary trunk',
        username: '1001',
        authUsername: '1001',
        domain: 'pbx.packetdial.local',
        displayName: 'PacketDial Desk',
        passwordRef: 'account:1001:password',
        registrar: 'sip:pbx.packetdial.local',
        transport: SipTransport.tls,
        registrationState: RegistrationState.unregistered,
        tlsEnabled: true,
        iceEnabled: true,
        srtpEnabled: true,
        isDefault: true,
      ),
    ];
  }

  String labelFor(List<SipAccount> accounts, String accountId) {
    for (final account in accounts) {
      if (account.id == accountId) {
        return account.label;
      }
    }
    return accountId;
  }
}
