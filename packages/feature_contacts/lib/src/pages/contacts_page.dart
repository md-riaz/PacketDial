import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';

import '../state/contact_list_state.dart';
import '../widgets/contact_editor_dialog.dart';
import '../widgets/contact_tile.dart';

class ContactsPage extends StatefulWidget {
  const ContactsPage({
    super.key,
    required this.contacts,
    required this.onDialContact,
    this.onContactsChanged,
  });

  final List<Contact> contacts;
  final ValueChanged<String> onDialContact;
  final ValueChanged<List<Contact>>? onContactsChanged;

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  late List<Contact> _contacts;
  ContactListState _viewState = const ContactListState();

  @override
  void initState() {
    super.initState();
    _contacts = widget.contacts.map((contact) => contact.copyWith()).toList();
  }

  @override
  void didUpdateWidget(covariant ContactsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.contacts, widget.contacts)) {
      _contacts = widget.contacts.map((contact) => contact.copyWith()).toList();
    }
  }

  void _commitContacts(List<Contact> contacts) {
    setState(() {
      _contacts = contacts;
    });
    widget.onContactsChanged?.call(contacts);
  }

  Future<void> _createContact() async {
    final created = await ContactEditorDialog.show(context);
    if (created == null) {
      return;
    }
    _commitContacts(<Contact>[created, ..._contacts]);
  }

  Future<void> _editContact(Contact contact) async {
    final updated = await ContactEditorDialog.show(
      context,
      initialContact: contact,
    );
    if (updated == null) {
      return;
    }
    _commitContacts(
      _contacts.map((item) => item.id == contact.id ? updated : item).toList(),
    );
  }

  void _toggleFavorite(Contact contact) {
    _commitContacts(
      _contacts
          .map(
            (item) => item.id == contact.id
                ? item.copyWith(isFavorite: !item.isFavorite)
                : item,
          )
          .toList(),
    );
  }

  void _deleteContact(Contact contact) {
    _commitContacts(
      _contacts.where((item) => item.id != contact.id).toList(growable: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _viewState.sort(
      _contacts.where(_viewState.matches).toList(growable: false),
    );
    final favoriteCount = _contacts
        .where((contact) => contact.isFavorite)
        .length;
    final isNarrow = MediaQuery.sizeOf(context).width < 700;

    return ListView(
      padding: EdgeInsets.all(isNarrow ? 16 : 24),
      children: [
        if (isNarrow)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Contacts',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              Text(
                '${_contacts.length} contacts - $favoriteCount favorites',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _createContact,
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: const Text('Add contact'),
              ),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Contacts',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_contacts.length} contacts - $favoriteCount favorites',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _createContact,
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: const Text('Add contact'),
              ),
            ],
          ),
        const SizedBox(height: 16),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Search contacts',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (value) {
            setState(() {
              _viewState = _viewState.copyWith(query: value);
            });
          },
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChip(
              selected: !_viewState.favoritesOnly,
              label: const Text('All'),
              onSelected: (_) {
                setState(() {
                  _viewState = _viewState.copyWith(favoritesOnly: false);
                });
              },
            ),
            FilterChip(
              selected: _viewState.favoritesOnly,
              label: const Text('Favorites only'),
              onSelected: (_) {
                setState(() {
                  _viewState = _viewState.copyWith(favoritesOnly: true);
                });
              },
            ),
            FilterChip(
              selected: _viewState.sortMode == ContactSortMode.favoritesFirst,
              label: const Text('Favorites first'),
              onSelected: (_) {
                setState(() {
                  _viewState = _viewState.copyWith(
                    sortMode: ContactSortMode.favoritesFirst,
                  );
                });
              },
            ),
            FilterChip(
              selected: _viewState.sortMode == ContactSortMode.alphabetical,
              label: const Text('A-Z'),
              onSelected: (_) {
                setState(() {
                  _viewState = _viewState.copyWith(
                    sortMode: ContactSortMode.alphabetical,
                  );
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (filtered.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('No contacts match the current filters.'),
            ),
          ),
        ...filtered.map(
          (contact) => ContactTile(
            contact: contact,
            onDial: () => widget.onDialContact(contact.extension),
            onToggleFavorite: () => _toggleFavorite(contact),
            onEdit: () => _editContact(contact),
            onDelete: () => _deleteContact(contact),
          ),
        ),
      ],
    );
  }
}
