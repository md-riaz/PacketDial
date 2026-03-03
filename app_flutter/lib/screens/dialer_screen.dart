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

  @override
  Widget build(BuildContext context) {
    final accountIds = _channel.accounts.keys.toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Dialer')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            if (accountIds.isNotEmpty)
              SizedBox(
                height: 48,
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedAccountId ?? accountIds.first,
                  decoration: const InputDecoration(
                    labelText: 'Account',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  ),
                  items: accountIds
                      .map((id) => DropdownMenuItem(
                          value: id,
                          child:
                              Text(id, style: const TextStyle(fontSize: 13))))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedAccountId = v),
                ),
              ),
            const SizedBox(height: 8),
            TextField(
              controller: _uriCtrl,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                labelText: 'SIP URI / Number',
                isDense: true,
                hintText: '100 or sip:alice@server',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.backspace, size: 18),
                  onPressed: _backspace,
                ),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            // Numpad
            for (final row in [
              ['1', '2', '3'],
              ['4', '5', '6'],
              ['7', '8', '9'],
              ['*', '0', '#'],
            ])
              Row(
                children: row
                    .map((label) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: OutlinedButton(
                              onPressed: () => _dialKey(label),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4)),
                              ),
                              child: Text(label,
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.normal)),
                            ),
                          ),
                        ))
                    .toList(),
              ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _call,
              icon: const Icon(Icons.call, size: 20),
              label: const Text('Call'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
