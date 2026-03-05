import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:window_manager/window_manager.dart';
import '../core/app_theme.dart';
import '../models/account_schema.dart';

class AccountSetupWindow extends StatefulWidget {
  final WindowController windowController;
  final AccountSchema? existing;

  const AccountSetupWindow({
    super.key,
    required this.windowController,
    this.existing,
  });

  @override
  State<AccountSetupWindow> createState() => _AccountSetupWindowState();
}

class _AccountSetupWindowState extends State<AccountSetupWindow> {
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
  bool _isClosing = false;

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

    // Set window size and center using bitsdojo_window
    WidgetsBinding.instance.addPostFrameCallback((_) {
      appWindow.minSize = const Size(400, 600);
      appWindow.size = const Size(450, 650);
      appWindow.alignment = Alignment.center;
      appWindow.title =
          widget.existing == null ? 'Add SIP Account' : 'Edit Account';
    });
    
    // Set up window method handler for close requests (desktop_multi_window pattern)
    _setupWindowHandler();
  }

  Future<void> _setupWindowHandler() async {
    await widget.windowController.setWindowMethodHandler((call) async {
      debugPrint('[AccountSetupWindow] Method called: ${call.method}');
      if (call.method == 'window_close') {
        await windowManager.close();
        return null;
      }
      throw MissingPluginException('Not implemented: ${call.method}');
    });
  }

  void _closeWindow() async {
    if (_isClosing) return;
    _isClosing = true;
    try {
      debugPrint('[AccountSetupWindow] Closing window');
      // Use invokeMethod('window_close') as per desktop_multi_window documentation
      await widget.windowController.invokeMethod('window_close');
    } catch (e) {
      debugPrint('[AccountSetupWindow] Error closing window: $e');
    }
  }

  @override
  void dispose() {
    debugPrint('[AccountSetupWindow] Disposing');
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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: Scaffold(
        backgroundColor: AppTheme.surface,
        // Native window title is used, so we remove the custom title bar
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
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
                decoration: const InputDecoration(
                  labelText: 'Account Label (e.g. Work)',
                  hintText: 'My Office Number',
                  prefixIcon: Icon(Icons.label_outline, size: 18),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: displayCtrl,
                enabled: !isRegistering,
                decoration: const InputDecoration(
                  labelText: 'Display Name (Optional)',
                  hintText: 'John Doe',
                  prefixIcon: Icon(Icons.person_outline, size: 18),
                ),
              ),
              const SizedBox(height: 16),
              _sectionLabel('Server'),
              TextField(
                controller: serverCtrl,
                enabled: !isRegistering,
                decoration: const InputDecoration(
                  labelText: 'SIP Server / Registrar',
                  hintText: 'sip.provider.com',
                  prefixIcon: Icon(Icons.dns_outlined, size: 18),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: userCtrl,
                enabled: !isRegistering,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  hintText: '1000',
                  prefixIcon: Icon(Icons.account_circle_outlined, size: 18),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: passCtrl,
                enabled: !isRegistering,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock_outline, size: 18),
                ),
              ),
              const SizedBox(height: 16),
              ExpansionTile(
                title: const Text('Advanced Settings',
                    style:
                        TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                tilePadding: EdgeInsets.zero,
                iconColor: AppTheme.textTertiary,
                collapsedIconColor: AppTheme.textTertiary,
                children: [
                  TextField(
                    controller: authUserCtrl,
                    enabled: !isRegistering,
                    decoration: const InputDecoration(
                        labelText: 'Auth Username (Optional)'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: domainCtrl,
                    enabled: !isRegistering,
                    decoration:
                        const InputDecoration(labelText: 'Domain (Optional)'),
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
                    dropdownColor: AppTheme.surfaceVariant,
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
                    style:
                        TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                value: autoRegister,
                onChanged: isRegistering
                    ? null
                    : (v) => setState(() => autoRegister = v ?? true),
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
        bottomNavigationBar: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariant,
            border: Border(
                top: BorderSide(color: AppTheme.border.withValues(alpha: 0.3))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: isRegistering ? null : _closeWindow,
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
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
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
      // IPC to main window to try registering
      final args = {
        'username': user,
        'password': pass,
        'server': server,
        'transport': transport,
        'domain': domainCtrl.text.trim(),
        'proxy': proxyCtrl.text.trim(),
      };

      final resultStr = await widget.windowController
          .invokeMethod('tryRegister', jsonEncode(args));
      final result = jsonDecode(resultStr ?? '{}') as Map<String, dynamic>;
      final success = result['success'] as bool? ?? false;

      if (!success) {
        if (mounted) {
          setState(() {
            isRegistering = false;
            registrationError = result['errorReason'] as String? ??
                'Registration failed. Check your credentials.';
          });
        }
        return;
      }

      // If registration succeeded, ask main window to save
      final schemaData = {
        'id': widget.existing?.id,
        'uuid': widget.existing?.uuid ?? '',
        'accountName': name,
        'displayName': displayCtrl.text.trim(),
        'server': server,
        'sipProxy': proxyCtrl.text.trim(),
        'username': user,
        'authUsername': authUserCtrl.text.trim(),
        'domain': domainCtrl.text.trim(),
        'password': pass,
        'transport': transport,
        'stunServer': stunCtrl.text.trim(),
        'turnServer': turnCtrl.text.trim(),
        'tlsEnabled': transport == 'tls',
        'srtpEnabled': srtpEnabled,
        'autoRegister': autoRegister,
        'isSelected': widget.existing?.isSelected ?? false,
      };

      await widget.windowController
          .invokeMethod('saveAccount', jsonEncode(schemaData));

      // Close via the coordinated close method
      if (mounted && !_isClosing) {
        _closeWindow();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isRegistering = false;
          registrationError = 'Failed to communicate with main process: $e';
        });
      }
    }
  }
}
