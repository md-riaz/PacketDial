import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_theme.dart';
import '../core/app_settings_service.dart';
import '../core/account_service.dart';
import '../core/contacts_service.dart';
import '../core/engine_channel.dart';
import '../models/account.dart';
import '../models/account_schema.dart';
import '../providers/contacts_provider.dart';
import '../widgets/app_search_bar.dart';
import '../widgets/stat_badge.dart';

/// Contacts tab for main navigation - shows BLF contacts with presence.
class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  String _searchQuery = '';
  String _filterPresence = 'All';
  StreamSubscription<Map<String, dynamic>>? _blfSub;

  static String _domainFromUri(String uri) {
    var s = uri.trim().toLowerCase();
    if (s.startsWith('sip:')) s = s.substring(4);
    if (s.startsWith('<')) s = s.substring(1);
    if (s.endsWith('>')) s = s.substring(0, s.length - 1);
    final at = s.indexOf('@');
    if (at >= 0) return s.substring(at + 1).split(':').first.trim();
    return '';
  }

  @override
  void initState() {
    super.initState();
    _blfSub = EngineChannel.instance.eventStream.listen((event) {
      if (event['type'] != 'BlfStatusChanged') return;
      final payload = event['payload'] as Map<String, dynamic>? ?? const {};
      final uri = payload['uri'] as String? ?? '';
      final state = payload['state'] as String? ?? 'Unknown';
      final activity = payload['activity'] as String?;
      final domain = _domainFromUri(uri);
      ref.read(contactsProvider.notifier).updatePresence(uri, state, activity, domain: domain);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_syncBlfSubscriptions());
    });
  }

  @override
  void dispose() {
    _blfSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allContacts = ref.watch(contactsProvider);
    final c = context.colors;

    return Container(
      decoration: BoxDecoration(gradient: c.pageGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('Contacts',
              style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 20)),
          actions: [
            IconButton(
              style: IconButton.styleFrom(
                backgroundColor: c.primary.withValues(alpha: 0.14),
                foregroundColor: c.primary,
              ),
              icon: const Icon(Icons.person_add_alt_1),
              onPressed: () => _showAddContactDialog(),
              tooltip: 'Add Contact',
            ),
            const SizedBox(width: 6),
            IconButton(
              style: IconButton.styleFrom(
                backgroundColor: c.accent.withValues(alpha: 0.14),
                foregroundColor: c.accentBright,
              ),
              icon: const Icon(Icons.refresh),
              onPressed: () => _refreshContacts(),
              tooltip: 'Refresh',
            ),
            const SizedBox(width: 10),
          ],
        ),
        body: Column(
          children: [
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AppSearchBar(
                hintText: 'Search contacts...',
                value: _searchQuery,
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip(context, 'All', c.primary),
                    const SizedBox(width: 8),
                    _buildFilterChip(context, 'Available', AppTheme.callGreen),
                    const SizedBox(width: 8),
                    _buildFilterChip(context, 'Busy', AppTheme.errorRed),
                    const SizedBox(width: 8),
                    _buildFilterChip(context, 'Ringing', AppTheme.warningAmber),
                    const SizedBox(width: 8),
                    _buildFilterChip(context, 'Away', const Color(0xFFFF9800)),
                    const SizedBox(width: 8),
                    _buildFilterChip(context, 'Offline', c.textTertiary),
                    const SizedBox(width: 8),
                    _buildFilterChip(context, 'Unknown', c.textTertiary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  StatBadge.pill(
                    icon: Icons.circle,
                    color: AppTheme.callGreen,
                    count: allContacts.where((c) => c.presenceState == 'Available').length.toString(),
                    label: 'Available',
                  ),
                  const SizedBox(width: 8),
                  StatBadge.pill(
                    icon: Icons.circle,
                    color: AppTheme.errorRed,
                    count: allContacts.where((c) => c.presenceState == 'Busy' || c.presenceState == 'Ringing').length.toString(),
                    label: 'Busy',
                  ),
                  const SizedBox(width: 8),
                  StatBadge.pill(
                    icon: Icons.circle,
                    color: c.textTertiary,
                    count: allContacts.where((c) => c.presenceState == 'Offline' || c.presenceState == 'Away' || c.presenceState == 'Unknown' || c.presenceState == 'Error').length.toString(),
                    label: 'Offline',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(child: _buildContactsList(context, allContacts)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(BuildContext context, String label, Color color) {
    final isSelected = _filterPresence == label;
    return FilterChip(
      label: Text(label,
          style: TextStyle(
            color: isSelected ? Colors.white : color,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 12,
          )),
      selected: isSelected,
      selectedColor: color.withValues(alpha: 0.92),
      backgroundColor: context.colors.surfaceCard,
      side: BorderSide(color: isSelected ? color.withValues(alpha: 0.95) : color.withValues(alpha: 0.28)),
      checkmarkColor: Colors.white,
      onSelected: (selected) => setState(() => _filterPresence = selected ? label : 'All'),
    );
  }

  Widget _buildContactsList(BuildContext context, List<BlfContact> allContacts) {
    final c = context.colors;
    var contacts = allContacts.where((c) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return c.name.toLowerCase().contains(q) ||
          c.sipUri.toLowerCase().contains(q) ||
          (c.extension?.toLowerCase().contains(q) ?? false);
    }).toList();

    if (_filterPresence != 'All') {
      contacts = contacts.where((c) => c.presenceState == _filterPresence).toList();
    }

    if (contacts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.contact_phone, size: 64, color: c.textTertiary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty
                  ? (_filterPresence == 'All' ? 'No contacts yet' : 'No contacts with this status')
                  : 'No contacts found',
              style: TextStyle(color: c.textTertiary, fontSize: 16),
            ),
            if (_searchQuery.isEmpty && _filterPresence == 'All') ...[
              const SizedBox(height: 8),
              Text('Tap + to add contacts or import from file',
                  style: TextStyle(color: c.textTertiary.withValues(alpha: 0.7), fontSize: 12)),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: contacts.length,
      itemBuilder: (context, index) {
        final contact = contacts[index];
        return _ContactTile(
          contact: contact,
          onCallPrimary: () => _callContact(contact),
          onCallExtension: contact.extension != null && contact.extension!.trim().isNotEmpty
              ? () => _callContact(contact, useExtension: true)
              : null,
          onPickup: contact.extension != null && contact.extension!.trim().isNotEmpty
              ? () => _pickupContact(contact)
              : null,
          onEdit: () => _showEditContactDialog(contact),
          onDelete: () => _confirmDeleteContact(contact),
        );
      },
    );
  }

  void _showAddContactDialog() {
    final nameCtrl = TextEditingController();
    final extCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final accounts = ref.read(accountServiceProvider).getAllAccounts();
    String? selectedAccountUuid = accounts.isNotEmpty ? accounts.first.uuid : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: ctx.colors.surfaceCard,
          title: Text('Add Contact', style: TextStyle(color: ctx.colors.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: _inputDeco(ctx, 'Name'), style: TextStyle(color: ctx.colors.textPrimary)),
              const SizedBox(height: 12),
              TextField(controller: extCtrl, decoration: _inputDeco(ctx, 'Extension (for BLF)'), style: TextStyle(color: ctx.colors.textPrimary)),
              const SizedBox(height: 12),
              TextField(controller: phoneCtrl, decoration: _inputDeco(ctx, 'Phone / SIP URI', hint: '+8801XXXXXXXXX'), keyboardType: TextInputType.phone, style: TextStyle(color: ctx.colors.textPrimary)),
              if (accounts.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedAccountUuid,
                  dropdownColor: ctx.colors.surfaceCard,
                  decoration: _inputDeco(ctx, 'Account (for BLF domain)'),
                  style: TextStyle(color: ctx.colors.textPrimary, fontSize: 14),
                  items: accounts.map((a) => DropdownMenuItem(value: a.uuid, child: Text(a.accountName))).toList(),
                  onChanged: (v) => setDialogState(() => selectedAccountUuid = v),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: ctx.colors.textSecondary))),
            FilledButton(
              onPressed: () async {
                if (nameCtrl.text.isNotEmpty && phoneCtrl.text.isNotEmpty) {
                  final domain = _domainForAccount(selectedAccountUuid);
                  await ref.read(contactsProvider.notifier).addContact(BlfContact(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameCtrl.text.trim(),
                    sipUri: phoneCtrl.text.trim(),
                    extension: extCtrl.text.trim().isNotEmpty ? extCtrl.text.trim() : null,
                    presenceDomain: domain,
                  ));
                  await _syncBlfSubscriptions();
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _refreshContacts() {
    ref.read(contactsProvider.notifier).loadContacts().then((_) async {
      await _syncBlfSubscriptions();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Contacts refreshed'),
        backgroundColor: AppTheme.callGreen,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 1),
      ));
    });
  }

  Future<void> _pickupContact(BlfContact contact) async {
    final account = _resolveBlfAccount();
    if (account == null) { _showFeedback('No registered account to pick up call.', color: AppTheme.warningAmber); return; }
    final ext = contact.extension?.trim() ?? '';
    if (ext.isEmpty) { _showFeedback('Contact has no extension for pickup.', color: AppTheme.warningAmber); return; }
    final rc = EngineChannel.instance.engine.makeCall(account.uuid, '**$ext');
    if (rc != 0) _showFeedback('Pickup failed (rc=$rc)', color: AppTheme.errorRed);
  }

  Future<void> _callContact(BlfContact contact, {bool useExtension = false}) async {
    final account = _resolveBlfAccount();
    if (account == null) { _showFeedback('Select or register an account before dialing contacts.', color: AppTheme.warningAmber); return; }
    final target = useExtension ? (contact.extension?.trim() ?? '') : contact.sipUri.trim();
    if (target.isEmpty) { _showFeedback('This contact does not have a callable target.', color: AppTheme.warningAmber); return; }
    final rc = EngineChannel.instance.engine.makeCall(account.uuid, target);
    if (rc != 0) _showFeedback('Failed to call ${contact.name} (rc=$rc)', color: AppTheme.errorRed);
  }

  void _showEditContactDialog(BlfContact contact) {
    final nameCtrl = TextEditingController(text: contact.name);
    final extCtrl = TextEditingController(text: contact.extension ?? '');
    final phoneCtrl = TextEditingController(text: contact.sipUri);
    final accounts = ref.read(accountServiceProvider).getAllAccounts();
    String? selectedAccountUuid = accounts
        .where((a) => _domainForAccount(a.uuid) == contact.presenceDomain)
        .map((a) => a.uuid)
        .firstOrNull ?? (accounts.isNotEmpty ? accounts.first.uuid : null);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: ctx.colors.surfaceCard,
          title: Text('Edit Contact', style: TextStyle(color: ctx.colors.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: _inputDeco(ctx, 'Name'), style: TextStyle(color: ctx.colors.textPrimary)),
              const SizedBox(height: 12),
              TextField(controller: extCtrl, decoration: _inputDeco(ctx, 'Extension (for BLF)'), style: TextStyle(color: ctx.colors.textPrimary)),
              const SizedBox(height: 12),
              TextField(controller: phoneCtrl, decoration: _inputDeco(ctx, 'Phone / SIP URI', hint: '+8801XXXXXXXXX'), keyboardType: TextInputType.phone, style: TextStyle(color: ctx.colors.textPrimary)),
              if (accounts.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedAccountUuid,
                  dropdownColor: ctx.colors.surfaceCard,
                  decoration: _inputDeco(ctx, 'Account (for BLF domain)'),
                  style: TextStyle(color: ctx.colors.textPrimary, fontSize: 14),
                  items: accounts.map((a) => DropdownMenuItem(value: a.uuid, child: Text(a.accountName))).toList(),
                  onChanged: (v) => setDialogState(() => selectedAccountUuid = v),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: ctx.colors.textSecondary))),
            FilledButton(
              onPressed: () async {
                if (nameCtrl.text.isEmpty || phoneCtrl.text.isEmpty) return;
                final domain = _domainForAccount(selectedAccountUuid);
                await ref.read(contactsProvider.notifier).updateContact(BlfContact(
                  id: contact.id,
                  name: nameCtrl.text.trim(),
                  sipUri: phoneCtrl.text.trim(),
                  extension: extCtrl.text.trim().isNotEmpty ? extCtrl.text.trim() : null,
                  presenceDomain: domain,
                  presenceState: contact.presenceState,
                  activity: contact.activity,
                ));
                await _syncBlfSubscriptions();
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteContact(BlfContact contact) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.colors.surfaceCard,
        title: Text('Delete Contact', style: TextStyle(color: ctx.colors.textPrimary)),
        content: Text('Delete "${contact.name}" from contacts?', style: TextStyle(color: ctx.colors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: ctx.colors.textSecondary))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorRed),
            onPressed: () async {
              await ref.read(contactsProvider.notifier).deleteContact(contact.id);
              await _syncBlfSubscriptions();
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _syncBlfSubscriptions() async {
    if (!AppSettingsService.instance.blfEnabled) return;
    final account = _resolveBlfAccount();
    if (account == null) return;
    final contacts = ref.read(contactsProvider);
    final uris = contacts
        .map((c) => _buildBlfTarget(c, account))
        .where((uri) => uri.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (uris.isEmpty) return;
    final engine = EngineChannel.instance.engine;
    engine.sendCommand('BlfUnsubscribe', jsonEncode({'account_id': account.uuid}));
    engine.sendCommand('BlfSubscribe', jsonEncode({'account_id': account.uuid, 'uris': uris}));
  }

  AccountSchema? _resolveBlfAccount() {
    final service = ref.read(accountServiceProvider);
    final selected = service.getSelectedAccount();
    if (selected != null) {
      final s = EngineChannel.instance.accounts[selected.uuid];
      if (s?.registrationState == RegistrationState.registered) return selected;
    }
    for (final account in service.getAllAccounts()) {
      final s = EngineChannel.instance.accounts[account.uuid];
      if (s?.registrationState == RegistrationState.registered) return account;
    }
    return null;
  }

  String _domainForAccount(String? uuid) {
    if (uuid == null) return '';
    final account = ref.read(accountServiceProvider).getAccountByUuid(uuid);
    if (account == null) return '';
    final d = account.domain.trim();
    if (d.isNotEmpty) return d;
    return account.server.trim().split(':').first;
  }

  String _buildBlfTarget(BlfContact contact, AccountSchema fallbackAccount) {
    final extension = contact.extension?.trim() ?? '';
    final domain = contact.presenceDomain.trim().isNotEmpty
        ? contact.presenceDomain.trim()
        : (fallbackAccount.domain.trim().isNotEmpty
            ? fallbackAccount.domain.trim()
            : fallbackAccount.server.trim().split(':').first);
    if (extension.isNotEmpty) {
      if (extension.contains('@') || extension.startsWith('sip:')) return extension;
      if (domain.isNotEmpty) return 'sip:$extension@$domain';
      return extension;
    }
    return contact.sipUri.trim();
  }

  InputDecoration _inputDeco(BuildContext ctx, String label, {String? hint}) {
    final c = ctx.colors;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(color: c.textTertiary),
      filled: true,
      fillColor: c.inputFill,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
    );
  }

  void _showFeedback(String message, {Color color = AppTheme.callGreen}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }
}

// ── Contact Tile ──────────────────────────────────────────────────────────────

class _ContactTile extends StatefulWidget {
  final BlfContact contact;
  final VoidCallback onCallPrimary;
  final VoidCallback? onCallExtension;
  final VoidCallback? onPickup;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ContactTile({
    required this.contact,
    required this.onCallPrimary,
    required this.onCallExtension,
    this.onPickup,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_ContactTile> createState() => _ContactTileState();
}

class _ContactTileState extends State<_ContactTile> with SingleTickerProviderStateMixin {
  late final AnimationController _blinkCtrl;

  @override
  void initState() {
    super.initState();
    _blinkCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _updateBlink();
  }

  @override
  void didUpdateWidget(_ContactTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contact.presenceState != widget.contact.presenceState) _updateBlink();
  }

  void _updateBlink() {
    if (widget.contact.presenceState == 'Ringing') {
      _blinkCtrl.repeat(reverse: true);
    } else {
      _blinkCtrl.stop();
      _blinkCtrl.value = 1.0;
    }
  }

  @override
  void dispose() {
    _blinkCtrl.dispose();
    super.dispose();
  }

  BlfContact get contact => widget.contact;

  Color _presenceColor(BuildContext context) {
    switch (contact.presenceState) {
      case 'Available': return AppTheme.callGreen;
      case 'Busy': return AppTheme.errorRed;
      case 'Ringing': return AppTheme.warningAmber;
      case 'Away': return const Color(0xFFFF9800);
      case 'Offline': return context.colors.textTertiary;
      case 'Error': return const Color(0xFFE040FB);
      default: return context.colors.textTertiary;
    }
  }

  IconData get _presenceIcon {
    switch (contact.presenceState) {
      case 'Available': return Icons.circle;
      case 'Busy': return Icons.do_not_disturb_on_outlined;
      case 'Ringing': return Icons.phone;
      case 'Away': return Icons.access_time;
      case 'Offline': return Icons.circle_outlined;
      case 'Error': return Icons.error_outline;
      default: return Icons.circle_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRinging = contact.presenceState == 'Ringing';
    final c = context.colors;
    return GestureDetector(
      onDoubleTap: isRinging ? widget.onPickup : null,
      child: Card(
        color: c.surfaceCard,
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          leading: AnimatedBuilder(
            animation: _blinkCtrl,
            builder: (_, child) => Opacity(
              opacity: isRinging ? 0.4 + _blinkCtrl.value * 0.6 : 1.0,
              child: child,
            ),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: _presenceColor(context).withValues(alpha: 0.16),
              child: Icon(Icons.person, color: _presenceColor(context), size: 20),
            ),
          ),
          title: Text(contact.name, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w600)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (contact.extension != null) ...[
                const SizedBox(height: 2),
                Text('Ext: ${contact.extension}',
                    style: TextStyle(color: c.primary.withValues(alpha: 0.9), fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
              ],
              if (contact.activity != null && contact.activity!.trim().isNotEmpty
                  && contact.activity!.trim().toLowerCase() != contact.presenceState.toLowerCase()) ...[
                Text(contact.activity!, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: c.textTertiary, fontSize: 10)),
                const SizedBox(height: 2),
              ],
              Text(contact.sipUri, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: c.textTertiary, fontSize: 11, fontFamily: 'monospace')),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _presenceColor(context).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _presenceColor(context).withValues(alpha: 0.32)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_presenceIcon, color: _presenceColor(context), size: 12),
                    const SizedBox(width: 4),
                    Text(contact.presenceState,
                        style: TextStyle(color: _presenceColor(context), fontSize: 10, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              PopupMenuButton<String>(
                color: c.surfaceCard,
                icon: Icon(Icons.more_vert, color: c.textTertiary),
                onSelected: (value) {
                  switch (value) {
                    case 'pickup': widget.onPickup?.call(); break;
                    case 'call_extension': widget.onCallExtension?.call(); break;
                    case 'call_primary': widget.onCallPrimary(); break;
                    case 'edit': widget.onEdit(); break;
                    case 'delete': widget.onDelete(); break;
                  }
                },
                itemBuilder: (ctx) {
                  final items = <PopupMenuEntry<String>>[];
                  final ext = contact.extension?.trim() ?? '';
                  final sipTarget = contact.sipUri.trim();
                  if (isRinging) {
                    items.add(const PopupMenuItem(value: 'pickup',
                        child: Row(children: [Icon(Icons.call_received, size: 18, color: AppTheme.warningAmber), SizedBox(width: 12), Text('Call Pickup', style: TextStyle(color: AppTheme.warningAmber))])));
                    items.add(const PopupMenuDivider());
                  }
                  if (ext.isNotEmpty) {
                    items.add(PopupMenuItem(value: 'call_extension',
                        child: Row(children: [Icon(Icons.dialpad, size: 18, color: ctx.colors.primary), const SizedBox(width: 12), Text('Call ext $ext')])));
                  }
                  if (sipTarget.isNotEmpty) {
                    items.add(PopupMenuItem(value: 'call_primary',
                        child: Row(children: [const Icon(Icons.call, size: 18, color: AppTheme.callGreen), const SizedBox(width: 12), SizedBox(width: 150, child: Text('Call $sipTarget', overflow: TextOverflow.ellipsis))])));
                  }
                  items.add(const PopupMenuDivider());
                  items.add(PopupMenuItem(value: 'edit',
                      child: Row(children: [Icon(Icons.edit_outlined, size: 18, color: ctx.colors.textPrimary), const SizedBox(width: 12), const Text('Edit contact')])));
                  items.add(const PopupMenuItem(value: 'delete',
                      child: Row(children: [Icon(Icons.delete_outline, size: 18, color: AppTheme.errorRed), SizedBox(width: 12), Text('Delete contact')])));
                  return items;
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
