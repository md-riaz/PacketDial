import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';

class AccountForm extends StatefulWidget {
  const AccountForm({super.key, required this.onCreateAccount});

  final Future<void> Function({
    required String label,
    required String username,
    required String authUsername,
    required String domain,
    required String displayName,
    required String password,
    required SipTransport transport,
    required bool tlsEnabled,
    required bool iceEnabled,
    required bool srtpEnabled,
    required String? outboundProxy,
    required String? stunServer,
    required String? turnServer,
    required int registerExpiresSeconds,
    required DtmfMode dtmfMode,
    required String? voicemailNumber,
    required List<String> codecs,
  })
  onCreateAccount;

  @override
  State<AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends State<AccountForm> {
  final _labelController = TextEditingController();
  final _usernameController = TextEditingController();
  final _authUsernameController = TextEditingController();
  final _domainController = TextEditingController(text: 'pbx.packetdial.local');
  final _displayNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _outboundProxyController = TextEditingController();
  final _stunServerController = TextEditingController();
  final _turnServerController = TextEditingController();
  final _voicemailController = TextEditingController();
  final _registerExpiresController = TextEditingController(text: '300');
  final _codecsController = TextEditingController(text: 'opus,pcmu,pcma');
  SipTransport _transport = SipTransport.tls;
  DtmfMode _dtmfMode = DtmfMode.rfc2833;
  bool _tlsEnabled = true;
  bool _iceEnabled = true;
  bool _srtpEnabled = true;

  @override
  void dispose() {
    _labelController.dispose();
    _usernameController.dispose();
    _authUsernameController.dispose();
    _domainController.dispose();
    _displayNameController.dispose();
    _passwordController.dispose();
    _outboundProxyController.dispose();
    _stunServerController.dispose();
    _turnServerController.dispose();
    _voicemailController.dispose();
    _registerExpiresController.dispose();
    _codecsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _field(_labelController, 'Label', width: 240),
            _field(_usernameController, 'Username', width: 180),
            _field(_authUsernameController, 'Auth username', width: 180),
            _field(_domainController, 'Domain', width: 220),
            _field(_displayNameController, 'Display name', width: 220),
            _field(
              _passwordController,
              'SIP password',
              width: 220,
              obscure: true,
            ),
            _transportDropdown(),
            _dtmfModeDropdown(),
            _field(_outboundProxyController, 'Outbound proxy', width: 220),
            _field(_stunServerController, 'STUN server', width: 220),
            _field(_turnServerController, 'TURN server', width: 220),
            _field(_voicemailController, 'Voicemail', width: 220),
            _field(
              _registerExpiresController,
              'Register expires',
              width: 160,
              keyboardType: TextInputType.number,
            ),
            _field(
              _codecsController,
              'Preferred codecs',
              width: 260,
              hint: 'opus,pcmu,pcma',
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilterChip(
              selected: _tlsEnabled,
              label: const Text('TLS'),
              onSelected: (value) {
                setState(() {
                  _tlsEnabled = value;
                  if (value) {
                    _transport = SipTransport.tls;
                  }
                });
              },
            ),
            FilterChip(
              selected: _iceEnabled,
              label: const Text('ICE'),
              onSelected: (value) {
                setState(() {
                  _iceEnabled = value;
                });
              },
            ),
            FilterChip(
              selected: _srtpEnabled,
              label: const Text('SRTP'),
              onSelected: (value) {
                setState(() {
                  _srtpEnabled = value;
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            onPressed: _submit,
            child: const Text('Create account'),
          ),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    required double width,
    bool obscure = false,
    TextInputType? keyboardType,
    String? hint,
  }) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label, hintText: hint),
      ),
    );
  }

  Widget _transportDropdown() {
    return SizedBox(
      width: 220,
      child: DropdownButtonFormField<SipTransport>(
        initialValue: _transport,
        decoration: const InputDecoration(labelText: 'Transport'),
        items: SipTransport.values
            .map(
              (value) => DropdownMenuItem<SipTransport>(
                value: value,
                child: Text(value.name.toUpperCase()),
              ),
            )
            .toList(),
        onChanged: (value) {
          if (value == null) {
            return;
          }
          setState(() {
            _transport = value;
            if (value == SipTransport.tls) {
              _tlsEnabled = true;
            }
          });
        },
      ),
    );
  }

  Widget _dtmfModeDropdown() {
    return SizedBox(
      width: 220,
      child: DropdownButtonFormField<DtmfMode>(
        initialValue: _dtmfMode,
        decoration: const InputDecoration(labelText: 'DTMF mode'),
        items: DtmfMode.values
            .map(
              (value) => DropdownMenuItem<DtmfMode>(
                value: value,
                child: Text(value.name),
              ),
            )
            .toList(),
        onChanged: (value) {
          if (value != null) {
            setState(() {
              _dtmfMode = value;
            });
          }
        },
      ),
    );
  }

  Future<void> _submit() async {
    await widget.onCreateAccount(
      label: _labelController.text.trim().isEmpty
          ? 'New trunk'
          : _labelController.text.trim(),
      username: _usernameController.text.trim().isEmpty
          ? '1002'
          : _usernameController.text.trim(),
      authUsername: _authUsernameController.text.trim().isEmpty
          ? (_usernameController.text.trim().isEmpty
                ? '1002'
                : _usernameController.text.trim())
          : _authUsernameController.text.trim(),
      domain: _domainController.text.trim(),
      displayName: _displayNameController.text.trim().isEmpty
          ? 'PacketDial User'
          : _displayNameController.text.trim(),
      password: _passwordController.text,
      transport: _transport,
      tlsEnabled: _tlsEnabled,
      iceEnabled: _iceEnabled,
      srtpEnabled: _srtpEnabled,
      outboundProxy: _outboundProxyController.text.trim(),
      stunServer: _stunServerController.text.trim(),
      turnServer: _turnServerController.text.trim(),
      registerExpiresSeconds:
          int.tryParse(_registerExpiresController.text.trim()) ?? 300,
      dtmfMode: _dtmfMode,
      voicemailNumber: _voicemailController.text.trim(),
      codecs: _codecsController.text
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(),
    );
    _labelController.clear();
    _usernameController.clear();
    _authUsernameController.clear();
    _displayNameController.clear();
    _passwordController.clear();
    _outboundProxyController.clear();
    _stunServerController.clear();
    _turnServerController.clear();
    _voicemailController.clear();
    _registerExpiresController.text = '300';
    _codecsController.text = 'opus,pcmu,pcma';
  }
}
