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

  void _dialKey(String digit) =>
      setState(() => _uriCtrl.text += digit);

  void _backspace() {
    if (_uriCtrl.text.isNotEmpty) {
      setState(() =>
          _uriCtrl.text = _uriCtrl.text.substring(0, _uriCtrl.text.length - 1));
    }
  }

  void _call() {
    final uri = _uriCtrl.text.trim();
    if (uri.isEmpty) return;
    final accountId = _selectedAccountId ??
        _channel.accounts.keys.firstOrNull ??
        '';
    if (accountId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configure and register an account first.')),
      );
      return;
    }
    _channel.sendCommand('CallStart', {'account_id': accountId, 'uri': uri});
  }

  Widget _dialButton(String label) => Expanded(
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: ElevatedButton(
            onPressed: () => _dialKey(label),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18),
            ),
            child: Text(label,
                style: const TextStyle(fontSize: 20)),
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
                value: _selectedAccountId ?? accountIds.first,
                decoration:
                    const InputDecoration(labelText: 'Account'),
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
                    icon: const Icon(Icons.backspace),
                    onPressed: _backspace),
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
              Row(
                  children:
                      row.map(_dialButton).toList()),
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
