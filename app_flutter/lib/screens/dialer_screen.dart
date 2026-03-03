import 'package:flutter/material.dart';

import '../core/engine_channel.dart';

class DialerScreen extends StatefulWidget {
  const DialerScreen({super.key});

  @override
  State<DialerScreen> createState() => _DialerScreenState();
}

class _DialerScreenState extends State<DialerScreen> {
  final _channel = EngineChannel.instance;
  final _uriCtrl = TextEditingController();
  String? _selectedAccountId;

  void _dialKey(String digit) => setState(() => _uriCtrl.text += digit);

  void _backspace() {
    if (_uriCtrl.text.isNotEmpty) {
      setState(() =>
          _uriCtrl.text = _uriCtrl.text.substring(0, _uriCtrl.text.length - 1));
    }
  }

  void _call() {
    final raw = _uriCtrl.text.trim();
    if (raw.isEmpty) return;

    final accounts = _channel.accounts;
    if (accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add an account first (Accounts tab).')),
      );
      return;
    }

    final accountId = _selectedAccountId ?? accounts.keys.first;
    final account = accounts[accountId];

    // Build a proper SIP URI if the user typed just a number/extension.
    // sip:127  →  sip:127@<server>   (server from the account config)
    String uri = raw;
    if (!uri.contains(':')) {
      // bare extension or number — prepend sip: and append @server
      final server = account?.server ?? '';
      uri = server.isNotEmpty ? 'sip:$raw@$server' : 'sip:$raw';
    } else if (!uri.startsWith('sip:') && !uri.startsWith('sips:')) {
      uri = 'sip:$raw';
    }

    _channel.engine.makeCall(accountId, uri);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Calling $uri …')),
    );
  }

  Widget _dialButton(String label) => Expanded(
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: ElevatedButton(
            onPressed: () => _dialKey(label),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18),
            ),
            child: Text(label, style: const TextStyle(fontSize: 20)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final accountIds = _channel.accounts.keys.toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Dialer')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (accountIds.isNotEmpty)
              DropdownButtonFormField<String>(
                initialValue: _selectedAccountId ?? accountIds.first,
                decoration: const InputDecoration(labelText: 'Account'),
                items: accountIds
                    .map((id) => DropdownMenuItem(value: id, child: Text(id)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedAccountId = v),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _uriCtrl,
              decoration: InputDecoration(
                labelText: 'SIP URI / Number',
                hintText: 'sip:alice@example.com',
                suffixIcon: IconButton(
                    icon: const Icon(Icons.backspace), onPressed: _backspace),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),
            // Numpad
            for (final row in [
              ['1', '2', '3'],
              ['4', '5', '6'],
              ['7', '8', '9'],
              ['*', '0', '#'],
            ])
              Row(children: row.map(_dialButton).toList()),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _call,
              icon: const Icon(Icons.call),
              label: const Text('Call'),
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52)),
            ),
          ],
        ),
      ),
    );
  }
}
