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
    final idCtrl =
        TextEditingController(text: existing?.id ?? '');
    final nameCtrl =
        TextEditingController(text: existing?.displayName ?? '');
    final serverCtrl =
        TextEditingController(text: existing?.server ?? '');
    final userCtrl =
        TextEditingController(text: existing?.username ?? '');
    final passCtrl =
        TextEditingController(text: existing?.password ?? '');
    final isNew = existing == null;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
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
              );
              _channel.accounts[id] = acct;
              _channel.sendCommand('AccountUpsert', {
                'id': acct.id,
                'display_name': acct.displayName,
                'server': acct.server,
                'username': acct.username,
                'password': acct.password,
              });
              Navigator.pop(ctx);
              setState(() {});
            },
            child: const Text('Save'),
          ),
        ],
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
          ? const Center(child: Text('No accounts configured.\nTap + to add one.'))
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
                      '${a.username}@${a.server}  •  ${a.registrationState.label}'),
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
