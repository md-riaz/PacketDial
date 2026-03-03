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
  void _showAccountDialog([AccountSchema? existing]) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AccountDialogBody(existing: existing),
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
                    selectedTileColor: Colors.indigo.withValues(alpha: 0.05),
                    leading: Icon(
                      isSelected ? Icons.check_circle : Icons.circle_outlined,
                      color: isSelected ? Colors.green : Colors.grey,
                    ),
                    title: Text(a.accountName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal)),
                    subtitle: Text(
                        a.displayName.isNotEmpty
                            ? '${a.displayName} (${a.username}@${a.server})'
                            : '${a.username}@${a.server}',
                        overflow: TextOverflow.ellipsis),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isSelected)
                          TextButton(
                            onPressed: () async {
                              await ref
                                  .read(accountServiceProvider)
                                  .setSelectedAccount(a.uuid);
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
                          onPressed: () => _showAccountDialog(a),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 18),
                          onPressed: () async {
                            await ref
                                .read(accountServiceProvider)
                                .deleteAccount(a.uuid);
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

class _AccountDialogBody extends ConsumerStatefulWidget {
  final AccountSchema? existing;
  const _AccountDialogBody({this.existing});

  @override
  ConsumerState<_AccountDialogBody> createState() => _AccountDialogBodyState();
}

class _AccountDialogBodyState extends ConsumerState<_AccountDialogBody> {
  final nameCtrl = TextEditingController();
  final displayCtrl = TextEditingController();
  final serverCtrl = TextEditingController();
  final userCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final authUserCtrl = TextEditingController();
  final domainCtrl = TextEditingController();
  final proxyCtrl = TextEditingController();
  final stunCtrl = TextEditingController();
  final turnCtrl = TextEditingController();

  String transport = 'udp';
  bool autoRegister = true;
  bool srtpEnabled = false;

  bool isRegistering = false;
  String? registrationError;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final e = widget.existing!;
      nameCtrl.text = e.accountName;
      displayCtrl.text = e.displayName;
      serverCtrl.text = e.server;
      userCtrl.text = e.username;
      passCtrl.text = e.password;
      authUserCtrl.text = e.authUsername;
      domainCtrl.text = e.domain;
      proxyCtrl.text = e.sipProxy;
      transport = e.transport;
      stunCtrl.text = e.stunServer;
      turnCtrl.text = e.turnServer;
      autoRegister = e.autoRegister;
      srtpEnabled = e.srtpEnabled;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add SIP Account' : 'Edit Account'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (registrationError != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.red, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          registrationError!,
                          style: TextStyle(
                              color: Colors.red.shade900, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              TextField(
                controller: nameCtrl,
                enabled: !isRegistering,
                decoration: const InputDecoration(
                  labelText: 'Account Label (e.g. Work)',
                  hintText: 'My Office Number',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: displayCtrl,
                enabled: !isRegistering,
                decoration: const InputDecoration(
                  labelText: 'Display Name (Optional)',
                  hintText: 'John Doe',
                ),
              ),
              const Divider(height: 32),
              TextField(
                controller: serverCtrl,
                enabled: !isRegistering,
                decoration: const InputDecoration(
                  labelText: 'SIP Server / Registrar',
                  hintText: 'sip.provider.com',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: userCtrl,
                enabled: !isRegistering,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  hintText: '1000',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: passCtrl,
                enabled: !isRegistering,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                ),
              ),
              const SizedBox(height: 16),
              ExpansionTile(
                title: const Text('Advanced Settings',
                    style: TextStyle(fontSize: 13)),
                tilePadding: EdgeInsets.zero,
                children: [
                  TextField(
                    controller: authUserCtrl,
                    enabled: !isRegistering,
                    decoration: const InputDecoration(
                      labelText: 'Auth Username (Optional)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: domainCtrl,
                    enabled: !isRegistering,
                    decoration: const InputDecoration(
                      labelText: 'Domain (Optional)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: proxyCtrl,
                    enabled: !isRegistering,
                    decoration: const InputDecoration(
                      labelText: 'SIP Proxy (Optional)',
                      helperText: 'Outbound proxy address if required.',
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: transport,
                    decoration: const InputDecoration(labelText: 'Transport'),
                    items: const [
                      DropdownMenuItem(value: 'udp', child: Text('UDP')),
                      DropdownMenuItem(value: 'tcp', child: Text('TCP')),
                      DropdownMenuItem(value: 'tls', child: Text('TLS')),
                    ],
                    onChanged: isRegistering
                        ? null
                        : (v) => setState(() => transport = v ?? 'udp'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: stunCtrl,
                    enabled: !isRegistering,
                    decoration: const InputDecoration(
                      labelText: 'STUN Server (Optional)',
                      helperText: 'For NAT traversal (e.g. stun.l.google.com)',
                    ),
                  ),
                ],
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Auto-register on startup',
                    style: TextStyle(fontSize: 14)),
                value: autoRegister,
                onChanged: isRegistering
                    ? null
                    : (v) => setState(() => autoRegister = v ?? true),
              ),
              // Registering indicator
              if (isRegistering) ...[
                const SizedBox(height: 12),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 12),
                    Text('Verifying SIP credentials…',
                        style: TextStyle(fontSize: 13, color: Colors.indigo)),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'This may take several seconds',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: isRegistering ? null : () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: isRegistering
              ? null
              : () async {
                  final name = nameCtrl.text.trim();
                  final server = serverCtrl.text.trim();
                  final user = userCtrl.text.trim();
                  final pass = passCtrl.text;

                  if (name.isEmpty ||
                      server.isEmpty ||
                      user.isEmpty ||
                      pass.isEmpty) {
                    setState(() {
                      registrationError = 'Please fill in all required fields.';
                    });
                    return;
                  }

                  // Start registration attempt
                  setState(() {
                    isRegistering = true;
                    registrationError = null;
                  });

                  final result =
                      await ref.read(accountServiceProvider).tryRegister(
                            username: user,
                            password: pass,
                            server: server,
                            transport: transport,
                            domain: domainCtrl.text.trim(),
                            proxy: proxyCtrl.text.trim(),
                          );

                  if (!result.success) {
                    // Registration failed — stay open
                    if (mounted) {
                      setState(() {
                        isRegistering = false;
                        registrationError = result.errorReason ??
                            'Registration failed. Check your credentials.';
                      });
                    }
                    return;
                  }

                  // Registration succeeded — save the account
                  final schema = AccountSchema()
                    ..id = widget.existing?.id
                    ..uuid = widget.existing?.uuid ?? ''
                    ..accountName = name
                    ..displayName = displayCtrl.text.trim()
                    ..server = server
                    ..sipProxy = proxyCtrl.text.trim()
                    ..username = user
                    ..authUsername = authUserCtrl.text.trim()
                    ..domain = domainCtrl.text.trim()
                    ..password = pass
                    ..transport = transport
                    ..stunServer = stunCtrl.text.trim()
                    ..turnServer = turnCtrl.text.trim()
                    ..tlsEnabled = (transport == 'tls')
                    ..srtpEnabled = srtpEnabled
                    ..autoRegister = autoRegister
                    ..isSelected = widget.existing?.isSelected ?? false;

                  await ref.read(accountServiceProvider).saveAccount(schema);

                  // Re-register with the real (saved) UUID so the account
                  // stays active — the trial registration used a temp UUID
                  // that was already cleaned up.
                  ref.read(accountServiceProvider).register(schema);

                  ref.invalidate(accountsListProvider);
                  if (mounted) Navigator.pop(context);
                },
          child: const Text('Save Account'),
        ),
      ],
    );
  }
}
