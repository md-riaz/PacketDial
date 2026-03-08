import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/app_theme.dart';
import '../core/account_service.dart';
import '../models/account_schema.dart';

class AccountSetupPage extends ConsumerStatefulWidget {
  final AccountSchema? existing;

  const AccountSetupPage({
    super.key,
    this.existing,
  });

  @override
  ConsumerState<AccountSetupPage> createState() => _AccountSetupPageState();
}

class _AccountSetupPageState extends ConsumerState<AccountSetupPage> {
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
  bool srtpEnabled = false;

  bool isRegistering = false;
  String? registrationError;

  @override
  void initState() {
    super.initState();
    _loadAccountData(widget.existing);
  }

  void _loadAccountData(AccountSchema? existing) {
    debugPrint('[AccountSetupPage] _loadAccountData called with ${existing == null ? "null" : "existing account: ${existing.accountName}"}');
    if (existing != null) {
      final e = existing;
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
      srtpEnabled = e.srtpEnabled;
      debugPrint('[AccountSetupPage] Loaded account: ${e.accountName}, server: ${e.server}, user: ${e.username}');
    } else {
      // Clear all fields for new account
      nameCtrl.clear();
      displayCtrl.clear();
      serverCtrl.clear();
      userCtrl.clear();
      passCtrl.clear();
      authUserCtrl.clear();
      domainCtrl.clear();
      proxyCtrl.clear();
      stunCtrl.clear();
      turnCtrl.clear();
      transport = 'udp';
      srtpEnabled = false;
    }
  }

  @override
  void dispose() {
    debugPrint('[AccountSetupPage] Disposing');
    nameCtrl.dispose();
    displayCtrl.dispose();
    serverCtrl.dispose();
    userCtrl.dispose();
    passCtrl.dispose();
    authUserCtrl.dispose();
    domainCtrl.dispose();
    proxyCtrl.dispose();
    stunCtrl.dispose();
    turnCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceVariant,
        elevation: 0,
        leading: BackButton(
          color: AppTheme.textPrimary,
        ),
        title: Text(
          isEdit ? 'Edit Account' : 'Add SIP Account',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (registrationError != null)
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.errorRed.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppTheme.errorRed.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: AppTheme.errorRed, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              registrationError!,
                              style: TextStyle(
                                color: AppTheme.errorRed.withValues(alpha: 0.9),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  _sectionLabel('Identity'),
                  TextField(
                    controller: nameCtrl,
                    enabled: !isRegistering,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Account Label (e.g. Work)',
                      hintText: 'My Office Number',
                      prefixIcon: const Icon(Icons.label_outline, size: 18),
                      labelStyle: TextStyle(color: AppTheme.textSecondary),
                      hintStyle: TextStyle(color: AppTheme.textTertiary),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppTheme.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppTheme.primary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: displayCtrl,
                    enabled: !isRegistering,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Display Name (Optional)',
                      hintText: 'John Doe',
                      prefixIcon: const Icon(Icons.person_outline, size: 18),
                      labelStyle: TextStyle(color: AppTheme.textSecondary),
                      hintStyle: TextStyle(color: AppTheme.textTertiary),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppTheme.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppTheme.primary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _sectionLabel('Server'),
                  TextField(
                    controller: serverCtrl,
                    enabled: !isRegistering,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'SIP Server / Registrar',
                      hintText: 'sip.provider.com',
                      prefixIcon: const Icon(Icons.dns_outlined, size: 18),
                      labelStyle: TextStyle(color: AppTheme.textSecondary),
                      hintStyle: TextStyle(color: AppTheme.textTertiary),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppTheme.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppTheme.primary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: userCtrl,
                    enabled: !isRegistering,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Username',
                      hintText: '1000',
                      prefixIcon: const Icon(Icons.account_circle_outlined, size: 18),
                      labelStyle: TextStyle(color: AppTheme.textSecondary),
                      hintStyle: TextStyle(color: AppTheme.textTertiary),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppTheme.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppTheme.primary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: passCtrl,
                    enabled: !isRegistering,
                    obscureText: true,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline, size: 18),
                      labelStyle: TextStyle(color: AppTheme.textSecondary),
                      hintStyle: TextStyle(color: AppTheme.textTertiary),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppTheme.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppTheme.primary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ExpansionTile(
                    title: const Text('Advanced Settings',
                        style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                    tilePadding: EdgeInsets.zero,
                    iconColor: AppTheme.textTertiary,
                    collapsedIconColor: AppTheme.textTertiary,
                    textColor: AppTheme.textSecondary,
                    children: [
                      TextField(
                        controller: authUserCtrl,
                        enabled: !isRegistering,
                        style: const TextStyle(color: AppTheme.textPrimary),
                        decoration: InputDecoration(
                            labelText: 'Auth Username (Optional)',
                            labelStyle: TextStyle(color: AppTheme.textSecondary),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: AppTheme.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: AppTheme.primary),
                            ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: domainCtrl,
                        enabled: !isRegistering,
                        style: const TextStyle(color: AppTheme.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Domain (Optional)',
                          labelStyle: TextStyle(color: AppTheme.textSecondary),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppTheme.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppTheme.primary),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: proxyCtrl,
                        enabled: !isRegistering,
                        style: const TextStyle(color: AppTheme.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'SIP Proxy (Optional)',
                          helperText: 'Outbound proxy address if required.',
                          labelStyle: TextStyle(color: AppTheme.textSecondary),
                          helperStyle: TextStyle(color: AppTheme.textTertiary, fontSize: 10),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppTheme.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppTheme.primary),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: transport,
                        decoration: InputDecoration(
                          labelText: 'Transport',
                          labelStyle: TextStyle(color: AppTheme.textSecondary),
                        ),
                        dropdownColor: AppTheme.surfaceVariant,
                        style: const TextStyle(color: AppTheme.textPrimary),
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
                        style: const TextStyle(color: AppTheme.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'STUN Server (Optional)',
                          helperText: 'For NAT traversal (e.g. stun.l.google.com)',
                          labelStyle: TextStyle(color: AppTheme.textSecondary),
                          helperStyle: TextStyle(color: AppTheme.textTertiary, fontSize: 10),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppTheme.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppTheme.primary),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (isRegistering) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppTheme.primary.withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(
                                  AppTheme.primary.withValues(alpha: 0.7)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Verifying SIP credentials…',
                                  style: TextStyle(
                                      fontSize: 13, color: AppTheme.primary)),
                              SizedBox(height: 2),
                              Text('This may take several seconds',
                                  style: TextStyle(
                                      fontSize: 10, color: AppTheme.textTertiary)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Fixed bottom action bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant,
              border: Border(
                  top: BorderSide(color: AppTheme.border.withValues(alpha: 0.3))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: isRegistering ? null : _cancel,
                  child: const Text('Cancel',
                      style: TextStyle(color: AppTheme.textTertiary)),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: isRegistering ? null : _saveAccount,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Save Account'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 16),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              gradient: AppTheme.accentGradient,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(text,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.textTertiary,
                letterSpacing: 1,
              )),
        ],
      ),
    );
  }

  void _cancel() {
    Navigator.of(context).pop(false);
  }

  Future<void> _saveAccount() async {
    final name = nameCtrl.text.trim();
    final server = serverCtrl.text.trim();
    final user = userCtrl.text.trim();
    final pass = passCtrl.text;

    if (name.isEmpty || server.isEmpty || user.isEmpty || pass.isEmpty) {
      setState(() {
        registrationError = 'Please fill in all required fields.';
      });
      return;
    }

    setState(() {
      isRegistering = true;
      registrationError = null;
    });

    try {
      final service = ref.read(accountServiceProvider);

      // Try registering first
      final result = await service.tryRegister(
        username: user,
        password: pass,
        server: server,
        transport: transport,
        domain: domainCtrl.text.trim(),
        proxy: proxyCtrl.text.trim(),
      );

      if (!result.success) {
        if (!mounted) return;
        setState(() {
          isRegistering = false;
          registrationError = result.errorReason ??
              'Registration failed. Check your credentials.';
        });
        return;
      }

      // Registration succeeded, save the account
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
        ..tlsEnabled = transport == 'tls'
        ..srtpEnabled = srtpEnabled
        ..autoRegister = true
        ..isSelected = widget.existing?.isSelected ?? false;

      await service.saveAccount(schema);
      service.register(schema);

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isRegistering = false;
        registrationError = 'Failed to save account: $e';
      });
    }
  }
}
