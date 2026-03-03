import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/account_service.dart';
import '../models/account_schema.dart';
import '../providers/engine_provider.dart';

final accountsListProvider = FutureProvider<List<AccountSchema>>((ref) {
  return ref.read(accountServiceProvider).getAllAccounts();
});

class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  void _showAccountDialog({AccountSchema? existing}) {
    final idCtrl = TextEditingController(text: existing?.accountId ?? '');
    final nameCtrl = TextEditingController(text: existing?.displayName ?? '');
    final serverCtrl = TextEditingController(
        text: existing?.server ?? 'cpx.alphapbx.net:8090');
    final userCtrl = TextEditingController(text: existing?.username ?? '');
    final passCtrl = TextEditingController(text: existing?.password ?? '');
    final stunCtrl = TextEditingController(text: existing?.stunServer ?? '');
    final turnCtrl = TextEditingController(text: existing?.turnServer ?? '');
    String transport = existing?.transport ?? 'udp';
    bool tlsEnabled = existing?.tlsEnabled ?? false;
    bool srtpEnabled = existing?.srtpEnabled ?? false;
    bool autoRegister = existing?.autoRegister ?? true;
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
                    decoration: const InputDecoration(labelText: 'SIP Server')),
                TextField(
                    controller: userCtrl,
                    decoration: const InputDecoration(labelText: 'Username')),
                TextField(
                    controller: passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: transport,
                  decoration: const InputDecoration(labelText: 'Transport'),
                  items: const [
                    DropdownMenuItem(value: 'udp', child: Text('UDP')),
                    DropdownMenuItem(value: 'tcp', child: Text('TCP')),
                    DropdownMenuItem(value: 'tls', child: Text('TLS')),
                  ],
                  onChanged: (v) => setDlgState(() => transport = v ?? 'udp'),
                ),
                TextField(
                    controller: stunCtrl,
                    decoration: const InputDecoration(
                        labelText: 'STUN Server (optional)')),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Auto-register on startup'),
                  value: autoRegister,
                  onChanged: (v) => setDlgState(() => autoRegister = v ?? true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final id = isNew ? idCtrl.text.trim() : existing.accountId;
                if (id.isEmpty) return;

                final schema = AccountSchema()
                  ..id = existing?.id
                  ..accountId = id
                  ..displayName = nameCtrl.text.trim()
                  ..server = serverCtrl.text.trim()
                  ..username = userCtrl.text.trim()
                  ..password = passCtrl.text
                  ..transport = transport
                  ..stunServer = stunCtrl.text.trim()
                  ..turnServer = turnCtrl.text.trim()
                  ..tlsEnabled = tlsEnabled
                  ..srtpEnabled = srtpEnabled
                  ..autoRegister = autoRegister
                  ..isSelected = existing?.isSelected ?? false;

                await ref.read(accountServiceProvider).saveAccount(schema);
                ref.invalidate(accountsListProvider);
                if (mounted) Navigator.pop(ctx);
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
    final accountsAsync = ref.watch(accountsListProvider);

    // Simple way to listen to global reg updates and refresh local UI list
    ref.listen(engineEventsProvider, (prev, next) {
      if (next.value?['type'] == 'RegistrationStateChanged') {
        ref.invalidate(accountsListProvider);
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Accounts')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAccountDialog(),
        mini: true,
        child: const Icon(Icons.add),
      ),
      body: accountsAsync.when(
        data: (accounts) => accounts.isEmpty
            ? const Center(child: Text('No accounts. Add one using +.'))
            : ListView.separated(
                padding: const EdgeInsets.all(8),
                itemCount: accounts.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final a = accounts[i];
                  // Registration state is handled in-memory by EngineChannel for now,
                  // but we display it here.
                  final isSelected = a.isSelected;
                  return ListTile(
                    dense: true,
                    selected: isSelected,
                    selectedTileColor: Colors.indigo.withOpacity(0.05),
                    leading: Icon(
                      isSelected ? Icons.check_circle : Icons.circle_outlined,
                      color: isSelected ? Colors.green : Colors.grey,
                    ),
                    title: Text(a.displayName,
                        style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal)),
                    subtitle: Text('${a.username}@${a.server}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isSelected)
                          TextButton(
                            onPressed: () async {
                              await ref
                                  .read(accountServiceProvider)
                                  .setSelectedAccount(a.accountId);
                              ref.invalidate(accountsListProvider);
                            },
                            child: const Text('Select'),
                          )
                        else
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text('Active',
                                style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12)),
                          ),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          onPressed: () => _showAccountDialog(existing: a),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 18),
                          onPressed: () async {
                            await ref
                                .read(accountServiceProvider)
                                .deleteAccount(a.accountId);
                            ref.invalidate(accountsListProvider);
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
