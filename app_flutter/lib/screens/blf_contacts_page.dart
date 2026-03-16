import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../core/app_theme.dart';
import '../core/contacts_service.dart';
import '../core/engine_channel.dart';
import '../models/account.dart';
import '../models/account_schema.dart';
import '../providers/contacts_provider.dart';
import '../core/account_service.dart';

/// BLF Contacts management page.
class BlfContactsPage extends ConsumerStatefulWidget {
  const BlfContactsPage({super.key});

  @override
  ConsumerState<BlfContactsPage> createState() => _BlfContactsPageState();
}

class _BlfContactsPageState extends ConsumerState<BlfContactsPage> {
  String _searchQuery = '';

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
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: c.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text('BLF Contacts',
              style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w600)),
          actions: [
            IconButton(
              icon: Icon(Icons.add, color: c.primary),
              onPressed: () => _showAddContactDialog(),
              tooltip: 'Add Contact',
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: c.textPrimary),
              onSelected: (value) {
                if (value == 'import') _importContacts();
                if (value == 'export') _exportContacts();
                if (value == 'clear') _clearAllContacts();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'import',
                  child: Row(
                    children: [
                      Icon(Icons.file_upload, size: 20),
                      SizedBox(width: 12),
                      Text('Import Contacts'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'export',
                  child: Row(
                    children: [
                      Icon(Icons.file_download, size: 20),
                      SizedBox(width: 12),
                      Text('Export Contacts'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'clear',
                  child: Row(
                    children: [
                      Icon(Icons.delete_sweep, size: 20, color: Colors.red),
                      SizedBox(width: 12),
                      Text('Clear All', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search contacts...',
                  hintStyle: TextStyle(color: context.colors.textTertiary),
                  filled: true,
                  fillColor: context.colors.inputFill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: Icon(Icons.search, color: context.colors.textTertiary),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: context.colors.textTertiary),
                          onPressed: () => setState(() => _searchQuery = ''),
                        )
                      : null,
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),

            // Stats row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildStatChip(
                    Icons.circle,
                    AppTheme.callGreen,
                    allContacts
                        .where((c) => c.presenceState == 'Available')
                        .length
                        .toString(),
                    'Available',
                  ),
                  const SizedBox(width: 8),
                  _buildStatChip(
                    Icons.circle,
                    AppTheme.errorRed,
                    allContacts
                        .where((c) => c.presenceState == 'Busy' || c.presenceState == 'Ringing')
                        .length
                        .toString(),
                    'Busy',
                  ),
                  const SizedBox(width: 8),
                  _buildStatChip(
                    Icons.circle,
                    const Color(0xFFFF9800),
                    allContacts
                        .where((c) => c.presenceState == 'Away')
                        .length
                        .toString(),
                    'Away',
                  ),
                  const SizedBox(width: 8),
                  _buildStatChip(
                    Icons.circle,
                    context.colors.textTertiary,
                    allContacts
                        .where((c) => c.presenceState == 'Offline' ||
                            c.presenceState == 'Unknown' ||
                            c.presenceState == 'Error')
                        .length
                        .toString(),
                    'Offline',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Contacts list
            Expanded(
              child: _buildContactsList(allContacts),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(
      IconData icon, Color color, String count, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 6),
          Text(
            count,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactsList(List<BlfContact> allContacts) {
    final contacts = allContacts.where((c) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      return c.name.toLowerCase().contains(query) ||
          c.sipUri.toLowerCase().contains(query) ||
          (c.extension?.toLowerCase().contains(query) ?? false);
    }).toList();

    if (contacts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.contact_phone, size: 64, color: context.colors.textTertiary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty ? 'No contacts yet' : 'No contacts found',
              style: TextStyle(color: context.colors.textTertiary, fontSize: 16),
            ),
            if (_searchQuery.isEmpty) ...[
              const SizedBox(height: 8),
              Text('Tap + to add contacts or import from file',
                  style: TextStyle(color: context.colors.textTertiary.withValues(alpha: 0.7), fontSize: 12)),
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
            onEdit: () => _showEditContactDialog(contact),
            onPickup: contact.extension != null && contact.extension!.trim().isNotEmpty
                ? () => _pickupContact(contact)
                : null,
        );
      },
    );
  }

  Future<void> _pickupContact(BlfContact contact) async {
    final service = ref.read(accountServiceProvider);
    AccountSchema? account;
    final selected = service.getSelectedAccount();
    if (selected != null &&
        EngineChannel.instance.accounts[selected.uuid]?.registrationState ==
            RegistrationState.registered) {
      account = selected;
    } else {
      for (final a in service.getAllAccounts()) {
        if (EngineChannel.instance.accounts[a.uuid]?.registrationState ==
            RegistrationState.registered) {
          account = a;
          break;
        }
      }
    }
    if (account == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No registered account for pickup'),
          backgroundColor: AppTheme.warningAmber,
          behavior: SnackBarBehavior.floating,
        ));
      }
      return;
    }
    final ext = contact.extension!.trim();
    EngineChannel.instance.engine.makeCall(account.uuid, '**$ext');
  }

  void _showAddContactDialog() {
    final nameCtrl = TextEditingController();
    final extCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.colors.surfaceCard,
        title: Text('Add BLF Contact', style: TextStyle(color: ctx.colors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _field(ctx, nameCtrl, 'Name'),
            const SizedBox(height: 12),
            _field(ctx, extCtrl, 'Extension (optional)'),
            const SizedBox(height: 12),
            _field(ctx, phoneCtrl, 'Phone number', hint: '+8801XXXXXXXXX', phone: true),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: ctx.colors.textSecondary))),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty && phoneCtrl.text.isNotEmpty) {
                ref.read(contactsProvider.notifier).addContact(BlfContact(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameCtrl.text,
                  sipUri: phoneCtrl.text,
                  extension: extCtrl.text.isNotEmpty ? extCtrl.text : null,
                ));
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _field(BuildContext ctx, TextEditingController ctrl, String label, {String? hint, bool phone = false}) {
    final c = ctx.colors;
    return TextField(
      controller: ctrl,
      keyboardType: phone ? TextInputType.phone : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: c.textTertiary),
        filled: true,
        fillColor: c.inputFill,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      ),
      style: TextStyle(color: c.textPrimary),
    );
  }

  void _showEditContactDialog(BlfContact contact) {
    final nameCtrl = TextEditingController(text: contact.name);
    final extCtrl = TextEditingController(text: contact.extension ?? '');
    final phoneCtrl = TextEditingController(text: contact.sipUri);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.colors.surfaceCard,
        title: Text('Edit Contact', style: TextStyle(color: ctx.colors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _field(ctx, nameCtrl, 'Name'),
            const SizedBox(height: 12),
            _field(ctx, extCtrl, 'Extension (optional)'),
            const SizedBox(height: 12),
            _field(ctx, phoneCtrl, 'Phone number', hint: '+8801XXXXXXXXX', phone: true),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: ctx.colors.textSecondary))),
          TextButton(
            onPressed: () { ref.read(contactsProvider.notifier).deleteContact(contact.id); Navigator.pop(ctx); },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
          FilledButton(
            onPressed: () {
              ref.read(contactsProvider.notifier).updateContact(BlfContact(
                id: contact.id,
                name: nameCtrl.text,
                sipUri: phoneCtrl.text,
                extension: extCtrl.text.isNotEmpty ? extCtrl.text : null,
                presenceState: contact.presenceState,
                activity: contact.activity,
              ));
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _importContacts() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final success =
            await ref.read(contactsProvider.notifier).importContacts(file);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  success ? 'Contacts imported successfully' : 'Import failed'),
              backgroundColor: success ? AppTheme.callGreen : AppTheme.errorRed,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to import contacts'),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _exportContacts() async {
    try {
      final file =
          await ref.read(contactsServiceProvider).getDefaultExportFile();
      final success =
          await ref.read(contactsServiceProvider).exportContacts(file);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Contacts exported to ${file.path}'
                : 'Export failed'),
            backgroundColor: success ? AppTheme.callGreen : AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to export contacts'),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _clearAllContacts() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.colors.surfaceCard,
        title: Text('Clear All Contacts', style: TextStyle(color: ctx.colors.textPrimary)),
        content: Text('Are you sure you want to delete all contacts? This cannot be undone.',
            style: TextStyle(color: ctx.colors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: ctx.colors.textSecondary))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorRed),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(contactsProvider.notifier).clearAll();
    }
  }
}

class _ContactTile extends StatefulWidget {
  final BlfContact contact;
  final VoidCallback onEdit;
  final VoidCallback? onPickup;

  const _ContactTile({required this.contact, required this.onEdit, this.onPickup});

  @override
  State<_ContactTile> createState() => _ContactTileState();
}

class _ContactTileState extends State<_ContactTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blinkCtrl;

  @override
  void initState() {
    super.initState();
    _blinkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _updateBlink();
  }

  @override
  void didUpdateWidget(_ContactTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contact.presenceState != widget.contact.presenceState) {
      _updateBlink();
    }
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
      case 'Available':
        return AppTheme.callGreen;
      case 'Busy':
        return AppTheme.errorRed;
      case 'Ringing':
        return AppTheme.warningAmber;
      case 'Away':
        return const Color(0xFFFF9800);
      case 'Offline':
        return context.colors.textTertiary;
      case 'Error':
        return const Color(0xFFE040FB);
      default:
        return context.colors.textTertiary;
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
          leading: AnimatedBuilder(
            animation: _blinkCtrl,
            builder: (_, child) => Opacity(
              opacity: isRinging ? 0.4 + _blinkCtrl.value * 0.6 : 1.0,
              child: child,
            ),
            child: CircleAvatar(
              backgroundColor: _presenceColor(context).withValues(alpha: 0.2),
              child: Icon(Icons.person, color: _presenceColor(context), size: 20),
            ),
          ),
          title: Text(contact.name,
              style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w600)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(contact.sipUri,
                  style: TextStyle(color: c.textTertiary, fontSize: 11, fontFamily: 'monospace')),
              if (contact.extension != null) ...[
                const SizedBox(height: 2),
                Text('Ext: ${contact.extension}',
                    style: TextStyle(color: c.primary.withValues(alpha: 0.8), fontSize: 11)),
              ],
              if (contact.activity != null) ...[
                const SizedBox(height: 2),
                Text(contact.activity!,
                    style: TextStyle(color: c.textTertiary, fontSize: 10, fontStyle: FontStyle.italic)),
              ],
            ],
          ),
          trailing: PopupMenuButton<String>(
            color: c.surfaceCard,
            icon: Icon(Icons.more_vert, color: c.textTertiary, size: 20),
            onSelected: (value) {
              if (value == 'pickup') widget.onPickup?.call();
              if (value == 'edit') widget.onEdit();
            },
            itemBuilder: (ctx) {
              final items = <PopupMenuEntry<String>>[];
              if (isRinging) {
                items.add(const PopupMenuItem(value: 'pickup',
                    child: Row(children: [Icon(Icons.call_received, size: 18, color: AppTheme.warningAmber), SizedBox(width: 12), Text('Call Pickup', style: TextStyle(color: AppTheme.warningAmber))])));
                items.add(const PopupMenuDivider());
              }
              items.add(PopupMenuItem(value: 'edit',
                  child: Row(children: [Icon(Icons.edit_outlined, size: 18, color: ctx.colors.textPrimary), const SizedBox(width: 12), const Text('Edit contact')])));
              return items;
            },
          ),
          onTap: widget.onEdit,
        ),
      ),
    );
  }
}
