import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../core/app_theme.dart';
import '../core/contacts_service.dart';

/// BLF Contacts management page.
class BlfContactsPage extends ConsumerStatefulWidget {
  const BlfContactsPage({super.key});

  @override
  ConsumerState<BlfContactsPage> createState() => _BlfContactsPageState();
}

class _BlfContactsPageState extends ConsumerState<BlfContactsPage> {
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    await ContactsService.instance.loadContacts();
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
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
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'BLF Contacts',
            style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.add, color: AppTheme.primary),
              onPressed: () => _showAddContactDialog(),
              tooltip: 'Add Contact',
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppTheme.textPrimary),
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
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(AppTheme.primary),
                ),
              )
            : Column(
                children: [
                  // Search bar
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search contacts...',
                        hintStyle: TextStyle(color: AppTheme.textTertiary),
                        filled: true,
                        fillColor: AppTheme.inputFill,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon: const Icon(Icons.search, color: AppTheme.textTertiary),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: AppTheme.textTertiary),
                                onPressed: () {
                                  setState(() => _searchQuery = '');
                                },
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
                          ContactsService.instance.getByPresence('Available').length.toString(),
                          'Available',
                        ),
                        const SizedBox(width: 8),
                        _buildStatChip(
                          Icons.circle,
                          AppTheme.errorRed,
                          ContactsService.instance.getByPresence('Busy').length.toString(),
                          'Busy',
                        ),
                        const SizedBox(width: 8),
                        _buildStatChip(
                          Icons.circle,
                          AppTheme.textTertiary,
                          ContactsService.instance.getByPresence('Unknown').length.toString(),
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

  Widget _buildStatChip(IconData icon, Color color, String count, String label) {
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
    final contacts = ContactsService.instance.contacts.where((c) {
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
            Icon(
              Icons.contact_phone,
              size: 64,
              color: AppTheme.textTertiary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty ? 'No contacts yet' : 'No contacts found',
              style: TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 16,
              ),
            ),
            if (_searchQuery.isEmpty) ...[
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
        return _ContactTile(contact: contact, onEdit: () => _showEditContactDialog(contact));
      },
    );
  }

  void _showAddContactDialog() {
    final nameCtrl = TextEditingController();
    final uriCtrl = TextEditingController();
    final extCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        title: const Text('Add BLF Contact',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: 'Name',
                labelStyle: TextStyle(color: AppTheme.textTertiary),
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
              controller: uriCtrl,
              decoration: InputDecoration(
                labelText: 'SIP URI',
                labelStyle: TextStyle(color: AppTheme.textTertiary),
                hintText: 'sip:user@domain.com',
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
                labelStyle: TextStyle(color: AppTheme.textTertiary),
                filled: true,
                fillColor: AppTheme.inputFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              style: const TextStyle(color: AppTheme.textPrimary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty && uriCtrl.text.isNotEmpty) {
                ContactsService.instance.addContact(BlfContact(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameCtrl.text,
                  sipUri: uriCtrl.text,
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

  void _showEditContactDialog(BlfContact contact) {
    final nameCtrl = TextEditingController(text: contact.name);
    final uriCtrl = TextEditingController(text: contact.sipUri);
    final extCtrl = TextEditingController(text: contact.extension ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        title: const Text('Edit Contact',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: 'Name',
                labelStyle: TextStyle(color: AppTheme.textTertiary),
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
              controller: uriCtrl,
              decoration: InputDecoration(
                labelText: 'SIP URI',
                labelStyle: TextStyle(color: AppTheme.textTertiary),
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
                labelText: 'Extension',
                labelStyle: TextStyle(color: AppTheme.textTertiary),
                filled: true,
                fillColor: AppTheme.inputFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              style: const TextStyle(color: AppTheme.textPrimary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              ContactsService.instance.deleteContact(contact.id);
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
          FilledButton(
            onPressed: () {
              ContactsService.instance.updateContact(BlfContact(
                id: contact.id,
                name: nameCtrl.text,
                sipUri: uriCtrl.text,
                extension: extCtrl.text.isNotEmpty ? extCtrl.text : null,
                presenceState: contact.presenceState,
                activity: contact.activity,
              ));
              Navigator.pop(context);
              setState(() {});
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
        final success = await ContactsService.instance.importContacts(file);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(success ? 'Contacts imported successfully' : 'Import failed'),
              backgroundColor: success ? AppTheme.callGreen : AppTheme.errorRed,
              behavior: SnackBarBehavior.floating,
            ),
          );
          setState(() {});
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
      final file = await ContactsService.instance.getDefaultExportFile();
      final success = await ContactsService.instance.exportContacts(file);
      
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
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        title: const Text('Clear All Contacts',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text(
          'Are you sure you want to delete all contacts? This cannot be undone.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorRed),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ContactsService.instance.clearAll();
      setState(() {});
    }
  }
}

class _ContactTile extends StatelessWidget {
  final BlfContact contact;
  final VoidCallback onEdit;

  const _ContactTile({required this.contact, required this.onEdit});

  Color get _presenceColor {
    switch (contact.presenceState) {
      case 'Available': return AppTheme.callGreen;
      case 'Busy': return AppTheme.errorRed;
      case 'Ringing': return AppTheme.warningAmber;
      default: return AppTheme.textTertiary;
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
          style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              contact.sipUri,
              style: TextStyle(
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
                style: TextStyle(
                  color: AppTheme.textTertiary,
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit, color: AppTheme.textTertiary, size: 20),
          onPressed: onEdit,
        ),
        onTap: onEdit,
      ),
    );
  }
}
