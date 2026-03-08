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
    serverCtrl.addListener(_onServerChanged);
  }

  void _onServerChanged() {
    // If domain is empty, keep it in sync with server
    if (domainCtrl.text.isEmpty) {
      domainCtrl.text = serverCtrl.text.trim();
    }
  }

  void _loadAccountData(AccountSchema? existing) {
    debugPrint(
        '[AccountSetupPage] _loadAccountData called with ${existing == null ? "null" : "existing account: ${existing.accountName}"}');
    if (existing != null) {
      final e = existing;
      nameCtrl.text = e.accountName;
      displayCtrl.text = e.displayName;
      serverCtrl.text = e.server;
      userCtrl.text = e.username;
      passCtrl.text = e.password;
      authUserCtrl.text = e.authUsername;
      domainCtrl.text = e.domain.isEmpty ? e.server : e.domain;
      proxyCtrl.text = e.sipProxy;
      if (domainCtrl.text.isNotEmpty) debugPrint('Domain: ${domainCtrl.text}');
      if (proxyCtrl.text.isNotEmpty) debugPrint('Proxy: ${proxyCtrl.text}');
      transport = e.transport;
      stunCtrl.text = e.stunServer;
      turnCtrl.text = e.turnServer;
      srtpEnabled = e.srtpEnabled;
      debugPrint(
          '[AccountSetupPage] Loaded account: ${e.accountName}, server: ${e.server}, user: ${e.username}');
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
                  _buildField(
                    controller: nameCtrl,
                    label: 'Account Label (e.g. Work)',
                    hint: 'My Office Number',
                    icon: Icons.label_outline,
                    enabled: !isRegistering,
                  ),
                  const SizedBox(height: 18),
                  _buildField(
                    controller: displayCtrl,
                    label: 'Display Name (Optional)',
                    hint: 'John Doe',
                    icon: Icons.person_outline,
                    enabled: !isRegistering,
                  ),
                  const SizedBox(height: 24),
                  _sectionLabel('Server'),
                  _buildField(
                    controller: serverCtrl,
                    label: 'SIP Server / Registrar',
                    hint: 'sip.provider.com',
                    icon: Icons.dns_outlined,
                    enabled: !isRegistering,
                  ),
                  const SizedBox(height: 18),
                  _buildField(
                    controller: userCtrl,
                    label: 'Username',
                    hint: '1000',
                    icon: Icons.account_circle_outlined,
                    enabled: !isRegistering,
                  ),
                  const SizedBox(height: 18),
                  _buildField(
                    controller: domainCtrl,
                    label: 'Domain',
                    hint: 'sip.provider.com:8090',
                    icon: Icons.domain_outlined,
                    enabled: !isRegistering,
                  ),
                  const SizedBox(height: 18),
                  _buildField(
                    controller: passCtrl,
                    label: 'Password',
                    icon: Icons.lock_outline,
                    enabled: !isRegistering,
                    obscure: true,
                  ),
                  const SizedBox(height: 24),
                  ExpansionTile(
                    title: const Text('Advanced Settings',
                        style: TextStyle(
                            fontSize: 13, color: AppTheme.textSecondary)),
                    tilePadding: EdgeInsets.zero,
                    iconColor: AppTheme.textTertiary,
                    collapsedIconColor: AppTheme.textTertiary,
                    textColor: AppTheme.textSecondary,
                    children: [
                      _buildField(
                        controller: authUserCtrl,
                        label: 'Auth Username (Optional)',
                        enabled: !isRegistering,
                      ),
                      const SizedBox(height: 18),
                      _buildField(
                        controller: proxyCtrl,
                        label: 'SIP Proxy (Optional)',
                        hint: 'Outbound proxy address if required.',
                        enabled: !isRegistering,
                      ),
                      const SizedBox(height: 18),
                      DropdownButtonFormField<String>(
                        value: transport,
                        decoration: InputDecoration(
                          labelText: 'Transport',
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 16, horizontal: 16),
                          labelStyle: TextStyle(color: AppTheme.textSecondary),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: AppTheme.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: AppTheme.primary, width: 2),
                          ),
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
                      const SizedBox(height: 18),
                      _buildField(
                        controller: stunCtrl,
                        label: 'STUN Server (Optional)',
                        hint: 'For NAT traversal (e.g. stun.l.google.com)',
                        enabled: !isRegistering,
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
                                      fontSize: 10,
                                      color: AppTheme.textTertiary)),
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
                  top: BorderSide(
                      color: AppTheme.border.withValues(alpha: 0.3))),
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
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
      padding: const EdgeInsets.only(bottom: 12, top: 4),
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

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? icon,
    bool obscure = false,
    bool enabled = true,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      obscureText: obscure,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon, size: 18) : null,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        labelStyle:
            const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        hintStyle: const TextStyle(color: AppTheme.textTertiary, fontSize: 13),
        helperStyle:
            const TextStyle(color: AppTheme.textTertiary, fontSize: 10),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppTheme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.primary, width: 2),
        ),
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
        stunServer: stunCtrl.text.trim(),
        authUsername: authUserCtrl.text.trim(),
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
      final rc = service.register(schema);
      if (rc != 0) {
        if (!mounted) return;
        setState(() {
          isRegistering = false;
          registrationError =
              'Account saved but registration command failed (rc=$rc).';
        });
        return;
      }

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
