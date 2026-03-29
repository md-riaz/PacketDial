import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';

class ContactEditorDialog extends StatefulWidget {
  const ContactEditorDialog({super.key, this.initialContact});

  final Contact? initialContact;

  static Future<Contact?> show(
    BuildContext context, {
    Contact? initialContact,
  }) {
    return showDialog<Contact>(
      context: context,
      builder: (context) => ContactEditorDialog(initialContact: initialContact),
    );
  }

  @override
  State<ContactEditorDialog> createState() => _ContactEditorDialogState();
}

class _ContactEditorDialogState extends State<ContactEditorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _extensionController;
  late final TextEditingController _presenceController;
  late final TextEditingController _notesController;
  late bool _isFavorite;

  @override
  void initState() {
    super.initState();
    final contact = widget.initialContact;
    _nameController = TextEditingController(text: contact?.name ?? '');
    _extensionController = TextEditingController(
      text: contact?.extension ?? '',
    );
    _presenceController = TextEditingController(
      text: contact?.presence ?? 'Offline',
    );
    _notesController = TextEditingController(text: contact?.notes ?? '');
    _isFavorite = contact?.isFavorite ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _extensionController.dispose();
    _presenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialContact != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit contact' : 'New contact'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _extensionController,
                decoration: const InputDecoration(labelText: 'Extension'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _presenceController,
                decoration: const InputDecoration(labelText: 'Presence'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _isFavorite,
                onChanged: (value) {
                  setState(() {
                    _isFavorite = value;
                  });
                },
                title: const Text('Favorite'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final name = _nameController.text.trim();
            final extension = _extensionController.text.trim();
            if (name.isEmpty || extension.isEmpty) {
              return;
            }
            Navigator.of(context).pop(
              Contact(
                id:
                    widget.initialContact?.id ??
                    DateTime.now().microsecondsSinceEpoch.toString(),
                name: name,
                extension: extension,
                presence: _presenceController.text.trim().isEmpty
                    ? 'Offline'
                    : _presenceController.text.trim(),
                notes: _notesController.text.trim(),
                isFavorite: _isFavorite,
              ),
            );
          },
          child: Text(isEditing ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}
