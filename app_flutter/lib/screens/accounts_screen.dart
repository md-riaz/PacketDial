import 'package:flutter/material.dart';

import '../core/engine_channel.dart';
import '../models/account.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  final _channel = EngineChannel.instance;

  @override
  void initState() {
    super.initState();
    _channel.events.listen((_) {
      if (mounted) setState(() {});
    });
  }

  void _showAccountDialog({Account? existing}) {
    final idCtrl = TextEditingController(text: existing?.id ?? '');
    final nameCtrl = TextEditingController(text: existing?.displayName ?? '');
    final serverCtrl = TextEditingController(text: existing?.server ?? '');
    final userCtrl = TextEditingController(text: existing?.username ?? '');
    final passCtrl = TextEditingController(text: existing?.password ?? '');
    final stunCtrl = TextEditingController(text: existing?.stunServer ?? '');
    final turnCtrl = TextEditingController(text: existing?.turnServer ?? '');
    String transport = existing?.transport ?? 'udp';
    bool tlsEnabled = existing?.tlsEnabled ?? false;
    bool srtpEnabled = existing?.srtpEnabled ?? false;
    final isNew = existing == null;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text(isNew ? 'Add Account' : 'Edit Account'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isNew)
                  TextField(
                      controller: idCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Account ID')),
                TextField(
                    controller: nameCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Display Name')),
                TextField(
                    controller: serverCtrl,
                    decoration:
                        const InputDecoration(labelText: 'SIP Server')),
                TextField(
                    controller: userCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Username')),
                TextField(
                    controller: passCtrl,
                    obscureText: true,
                    decoration:
                        const InputDecoration(labelText: 'Password')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: transport,
                  decoration:
                      const InputDecoration(labelText: 'Transport'),
                  items: const [
                    DropdownMenuItem(value: 'udp', child: Text('UDP')),
                    DropdownMenuItem(value: 'tcp', child: Text('TCP')),
                  ],
                  onChanged: (v) =>
                      setDlgState(() => transport = v ?? 'udp'),
                ),
                const SizedBox(height: 4),
                TextField(
                    controller: stunCtrl,
                    decoration: const InputDecoration(
                        labelText: 'STUN Server (optional)',
                        hintText: 'stun.example.com:3478')),
                TextField(
                    controller: turnCtrl,
                    decoration: const InputDecoration(
                        labelText: 'TURN Server (optional)',
                        hintText: 'turn.example.com:3478')),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enable TLS (SIPS)'),
                  subtitle: const Text('Encrypts SIP signalling'),
                  value: tlsEnabled,
                  onChanged: (v) =>
                      setDlgState(() => tlsEnabled = v ?? false),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enable SRTP'),
                  subtitle: const Text('Encrypts audio media'),
                  value: srtpEnabled,
                  onChanged: (v) =>
                      setDlgState(() => srtpEnabled = v ?? false),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final id = isNew ? idCtrl.text.trim() : existing.id;
                if (id.isEmpty) return;
                final acct = Account(
                  id: id,
                  displayName: nameCtrl.text.trim(),
                  server: serverCtrl.text.trim(),
                  username: userCtrl.text.trim(),
                  password: passCtrl.text,
                  transport: transport,
                  stunServer: stunCtrl.text.trim(),
                  turnServer: turnCtrl.text.trim(),
                  tlsEnabled: tlsEnabled,
                  srtpEnabled: srtpEnabled,
                );
                _channel.accounts[id] = acct;
                _channel.sendCommand('AccountUpsert', {
                  'id': acct.id,
                  'display_name': acct.displayName,
                  'server': acct.server,
                  'username': acct.username,
                  'password': acct.password,
                  'transport': acct.transport,
                  'stun_server': acct.stunServer,
                  'turn_server': acct.turnServer,
                  'tls_enabled': acct.tlsEnabled,
                  'srtp_enabled': acct.srtpEnabled,
                });
                Navigator.pop(ctx);
                setState(() {});
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accounts = _channel.accounts.values.toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Accounts')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAccountDialog(),
        tooltip: 'Add Account',
        child: const Icon(Icons.add),
      ),
      body: accounts.isEmpty
          ? const Center(
              child: Text('No accounts configured.\nTap + to add one.'))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: accounts.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (_, i) {
                final a = accounts[i];
                final registered =
                    a.registrationState == RegistrationState.registered;
                return ListTile(
                  leading: Icon(
                    Icons.person,
                    color: registered ? Colors.green : Colors.grey,
                  ),
                  title: Text(a.displayName.isEmpty ? a.id : a.displayName),
                  subtitle: Text(
                      '${a.username}@${a.server}  •  ${a.transport.toUpperCase()}${a.tlsEnabled ? ' + TLS' : ''}${a.srtpEnabled ? ' + SRTP' : ''}  •  ${a.registrationState.label}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!registered)
                        TextButton(
                          onPressed: () => _channel
                              .sendCommand('AccountRegister', {'id': a.id}),
                          child: const Text('Register'),
                        )
                      else
                        TextButton(
                          onPressed: () => _channel.sendCommand(
                              'AccountUnregister', {'id': a.id}),
                          child: const Text('Unregister'),
                        ),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showAccountDialog(existing: a),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
