import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/engine_channel.dart';
import '../core/account_service.dart';
import '../models/account_schema.dart';
import '../models/call.dart';
import '../models/media_stats.dart';
import '../providers/engine_provider.dart';

final selectedAccountProvider = FutureProvider<AccountSchema?>((ref) {
  return ref.read(accountServiceProvider).getSelectedAccount();
});

class DialerScreen extends ConsumerStatefulWidget {
  const DialerScreen({super.key});

  @override
  ConsumerState<DialerScreen> createState() => _DialerScreenState();
}

class _DialerScreenState extends ConsumerState<DialerScreen> {
  final _uriCtrl = TextEditingController();

  void _dialKey(String digit) => setState(() => _uriCtrl.text += digit);

  void _backspace() {
    if (_uriCtrl.text.isNotEmpty) {
      setState(() =>
          _uriCtrl.text = _uriCtrl.text.substring(0, _uriCtrl.text.length - 1));
    }
  }

  void _call(AccountSchema? activeAccount) {
    if (activeAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active account selected.')),
      );
      return;
    }

    final raw = _uriCtrl.text.trim();
    if (raw.isEmpty) return;

    final accountId = activeAccount.accountId;
    final server = activeAccount.server;

    String uri = raw;
    if (!uri.contains(':')) {
      uri = server.isNotEmpty ? 'sip:$raw@$server' : 'sip:$raw';
    } else if (!uri.startsWith('sip:') && !uri.startsWith('sips:')) {
      uri = 'sip:$raw';
    }

    EngineChannel.instance.engine.makeCall(accountId, uri);
  }

  void _hangup() => EngineChannel.instance.engine.hangup();
  void _toggleMute(ActiveCall call) =>
      EngineChannel.instance.engine.setMute(!call.muted);
  void _toggleHold(ActiveCall call) =>
      EngineChannel.instance.engine.setHold(!call.onHold);

  @override
  Widget build(BuildContext context) {
    final activeAccountAsync = ref.watch(selectedAccountProvider);
    final activeCall = ref.watch(activeCallProvider);
    final stats = ref.watch(activeCallMediaStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(activeCall != null ? 'Active Call' : 'Dialer'),
        centerTitle: true,
      ),
      body: activeAccountAsync.when(
        data: (activeAccount) => SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              // 1. Account / Call Status Header
              _buildHeader(activeAccount, activeCall),
              const SizedBox(height: 16),

              // 2. Main Content Area (Visuals or Input)
              if (activeCall != null)
                _buildActiveCallUI(activeCall, stats)
              else
                _buildDialerInput(),

              const SizedBox(height: 16),

              // 3. Numpad (Always available for DTMF during calls)
              _buildNumpad(),

              const SizedBox(height: 16),

              // 4. Primary Action (Call or Hangup)
              if (activeCall != null)
                _buildCallControls(activeCall)
              else
                _buildDialButton(activeAccount),

              // 5. Media Stats (Optional, expanded)
              if (activeCall != null && stats != null) ...[
                const SizedBox(height: 16),
                _MediaStatsView(stats: stats),
              ],
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildHeader(AccountSchema? account, ActiveCall? call) {
    bool isCall = call != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: (isCall ? Colors.green : Colors.indigo).withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: (isCall ? Colors.green : Colors.indigo).withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                isCall ? Icons.call : Icons.account_circle,
                size: 18,
                color: isCall ? Colors.green : Colors.indigo,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isCall
                      ? 'On Call: ${call.uri}'
                      : (account != null
                          ? 'Active: ${account.displayName}'
                          : 'No Account'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color:
                        isCall ? Colors.green.shade700 : Colors.indigo.shade700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isCall)
                Text(
                  call.state.label.toUpperCase(),
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Colors.green),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveCallUI(ActiveCall call, MediaStats? stats) {
    return Column(
      children: [
        const Icon(Icons.person, size: 64, color: Colors.indigo),
        const SizedBox(height: 8),
        Text(call.uri,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(call.state.label,
            style: const TextStyle(color: Colors.grey, fontSize: 13)),
      ],
    );
  }

  Widget _buildDialerInput() {
    return TextField(
      controller: _uriCtrl,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        hintText: 'Enter URI or Number',
        border: InputBorder.none,
        suffixIcon: IconButton(
          icon: const Icon(Icons.backspace_outlined, size: 20),
          onPressed: _backspace,
        ),
      ),
    );
  }

  Widget _buildNumpad() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      childAspectRatio: 1.5,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: [
        for (final label in [
          '1',
          '2',
          '3',
          '4',
          '5',
          '6',
          '7',
          '8',
          '9',
          '*',
          '0',
          '#'
        ])
          OutlinedButton(
            onPressed: () => _dialKey(label),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(label, style: const TextStyle(fontSize: 20)),
          ),
      ],
    );
  }

  Widget _buildDialButton(AccountSchema? account) {
    return FilledButton.icon(
      onPressed: () => _call(account),
      icon: const Icon(Icons.call),
      label: const Text('Dial'),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        backgroundColor: Colors.green.shade600,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildCallControls(ActiveCall call) {
    return Row(
      children: [
        Expanded(
          child: _controlButton(
            icon: call.muted ? Icons.mic_off : Icons.mic,
            label: call.muted ? 'Unmute' : 'Mute',
            active: call.muted,
            onTap: () => _toggleMute(call),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _controlButton(
            icon: call.onHold ? Icons.play_arrow : Icons.pause,
            label: call.onHold ? 'Resume' : 'Hold',
            active: call.onHold,
            onTap: () => _toggleHold(call),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton.icon(
            onPressed: _hangup,
            icon: const Icon(Icons.call_end),
            label: const Text('End'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: Colors.red.shade600,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _controlButton(
      {required IconData icon,
      required String label,
      required bool active,
      required VoidCallback onTap}) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        backgroundColor: active ? Colors.orange.withOpacity(0.1) : null,
        side: BorderSide(color: active ? Colors.orange : Colors.grey.shade300),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: active ? Colors.orange : Colors.indigo),
          Text(label,
              style: TextStyle(
                  fontSize: 10, color: active ? Colors.orange : null)),
        ],
      ),
    );
  }
}

class _MediaStatsView extends StatelessWidget {
  final MediaStats stats;
  const _MediaStatsView({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Quality Metrics',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _statItem('Codec', stats.codec),
              _statItem('Jitter', '${stats.jitterMs.round()}ms'),
              _statItem('Loss', '${stats.packetLossPct.toStringAsFixed(1)}%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)),
        Text(value,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
