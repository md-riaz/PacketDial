import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_theme.dart';
import '../core/contacts_service.dart';
import '../core/engine_channel.dart';

/// Contacts tab for main navigation - shows BLF contacts with presence.
class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  String _searchQuery = '';
  String _filterPresence = 'All';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D0D1A), Color(0xFF1A1040)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            'Contacts',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.add, color: AppTheme.primary),
              onPressed: () => _showAddContactDialog(),
              tooltip: 'Add Contact',
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: AppTheme.textPrimary),
              onPressed: () => _refreshContacts(),
              tooltip: 'Refresh',
            ),
          ],
        ),
        body: Column(
          children: [
            const SizedBox(height: 16),

            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search contacts...',
                  hintStyle: const TextStyle(color: AppTheme.textTertiary),
                  filled: true,
                  fillColor: AppTheme.inputFill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon:
                      const Icon(Icons.search, color: AppTheme.textTertiary),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear,
                              color: AppTheme.textTertiary),
                          onPressed: () {
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),

            const SizedBox(height: 16),

            // Presence filter chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('All', Colors.grey),
                    const SizedBox(width: 8),
                    _buildFilterChip('Available', AppTheme.callGreen),
                    const SizedBox(width: 8),
                    _buildFilterChip('Busy', AppTheme.errorRed),
                    const SizedBox(width: 8),
                    _buildFilterChip('Unknown', AppTheme.textTertiary),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Stats row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildStatChip(
                    Icons.circle,
                    AppTheme.callGreen,
                    ContactsService.instance
                        .getByPresence('Available')
                        .length
                        .toString(),
                    'Available',
                  ),
                  const SizedBox(width: 8),
                  _buildStatChip(
                    Icons.circle,
                    AppTheme.errorRed,
                    ContactsService.instance
                        .getByPresence('Busy')
                        .length
                        .toString(),
                    'Busy',
                  ),
                  const SizedBox(width: 8),
                  _buildStatChip(
                    Icons.circle,
                    AppTheme.textTertiary,
                    ContactsService.instance
                        .getByPresence('Unknown')
                        .length
                        .toString(),
                    'Unknown',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Contacts list
            Expanded(
              child: _buildContactsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, Color color) {
    final isSelected = _filterPresence == label;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : color,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          fontSize: 12,
        ),
      ),
      selected: isSelected,
      selectedColor: color,
      backgroundColor: color.withValues(alpha: 0.1),
      checkmarkColor: Colors.white,
      onSelected: (selected) {
        setState(() => _filterPresence = selected ? label : 'All');
      },
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

  Widget _buildContactsList() {
    var contacts = ContactsService.instance.contacts.where((c) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      return c.name.toLowerCase().contains(query) ||
          c.sipUri.toLowerCase().contains(query) ||
          (c.extension?.toLowerCase().contains(query) ?? false);
    }).toList();

    if (_filterPresence != 'All') {
      contacts =
          contacts.where((c) => c.presenceState == _filterPresence).toList();
    }

    if (contacts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.contact_phone,
              size: 64,
              color: AppTheme.textTertiary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty
                  ? (_filterPresence == 'All'
                      ? 'No contacts yet'
                      : 'No contacts with this status')
                  : 'No contacts found',
              style: const TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 16,
              ),
            ),
            if (_searchQuery.isEmpty && _filterPresence == 'All') ...[
              const SizedBox(height: 8),
              Text(
                'Tap + to add contacts or import from file',
                style: TextStyle(
                  color: AppTheme.textTertiary.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
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
        return _ContactTile(contact: contact);
      },
    );
  }

  void _showAddContactDialog() {
    final nameCtrl = TextEditingController();
    final extCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        title: const Text('Add Contact',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: 'Name',
                labelStyle: const TextStyle(color: AppTheme.textTertiary),
                filled: true,
                fillColor: AppTheme.inputFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              style: const TextStyle(color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: extCtrl,
              decoration: InputDecoration(
                labelText: 'Extension (optional)',
                labelStyle: const TextStyle(color: AppTheme.textTertiary),
                filled: true,
                fillColor: AppTheme.inputFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              style: const TextStyle(color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              decoration: InputDecoration(
                labelText: 'Phone number',
                labelStyle: const TextStyle(color: AppTheme.textTertiary),
                hintText: '+8801XXXXXXXXX',
                filled: true,
                fillColor: AppTheme.inputFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: AppTheme.textPrimary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty && phoneCtrl.text.isNotEmpty) {
                ContactsService.instance.addContact(BlfContact(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameCtrl.text,
                  sipUri: phoneCtrl.text,
                  extension: extCtrl.text.isNotEmpty ? extCtrl.text : null,
                ));
                Navigator.pop(context);
                setState(() {});
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _refreshContacts() {
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Contacts refreshed'),
        backgroundColor: AppTheme.callGreen,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 1),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final BlfContact contact;

  const _ContactTile({required this.contact});

  Color get _presenceColor {
    switch (contact.presenceState) {
      case 'Available':
        return AppTheme.callGreen;
      case 'Busy':
        return AppTheme.errorRed;
      case 'Ringing':
        return AppTheme.warningAmber;
      default:
        return AppTheme.textTertiary;
    }
  }

  IconData get _presenceIcon {
    switch (contact.presenceState) {
      case 'Available':
        return Icons.check_circle;
      case 'Busy':
        return Icons.remove_circle;
      case 'Ringing':
        return Icons.phone;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.surfaceCard,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _presenceColor.withValues(alpha: 0.2),
          child: Icon(
            Icons.person,
            color: _presenceColor,
            size: 20,
          ),
        ),
        title: Text(
          contact.name,
          style: const TextStyle(
              color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              contact.sipUri,
              style: const TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
            if (contact.extension != null) ...[
              const SizedBox(height: 2),
              Text(
                'Ext: ${contact.extension}',
                style: TextStyle(
                  color: AppTheme.primary.withValues(alpha: 0.8),
                  fontSize: 11,
                ),
              ),
            ],
            if (contact.activity != null) ...[
              const SizedBox(height: 2),
              Text(
                contact.activity!,
                style: const TextStyle(
                  color: AppTheme.textTertiary,
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _presenceColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _presenceColor.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _presenceIcon,
                    color: _presenceColor,
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    contact.presenceState,
                    style: TextStyle(
                      color: _presenceColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppTheme.textTertiary),
              onSelected: (value) {
                if (value == 'call') {
                  // Dial the contact
                  EngineChannel.instance.engine.makeCall(
                    EngineChannel.instance.accounts.values.first.uuid,
                    contact.sipUri,
                  );
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'call',
                  child: Row(
                    children: [
                      Icon(Icons.call, size: 20, color: AppTheme.callGreen),
                      SizedBox(width: 12),
                      Text('Call'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
