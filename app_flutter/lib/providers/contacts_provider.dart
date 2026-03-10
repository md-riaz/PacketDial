import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/contacts_service.dart';

final contactsServiceProvider = Provider<ContactsService>((ref) {
  return ContactsService.instance;
});

final contactsProvider =
    NotifierProvider<ContactsNotifier, List<BlfContact>>(() {
  return ContactsNotifier();
});

class ContactsNotifier extends Notifier<List<BlfContact>> {
  late ContactsService _service;

  @override
  List<BlfContact> build() {
    _service = ref.read(contactsServiceProvider);
    return _service.contacts;
  }

  void _refresh() {
    state = List.unmodifiable(_service.contacts);
  }

  Future<void> loadContacts() async {
    await _service.loadContacts();
    _refresh();
  }

  Future<void> addContact(BlfContact contact) async {
    await _service.addContact(contact);
    _refresh();
  }

  Future<void> updateContact(BlfContact contact) async {
    await _service.updateContact(contact);
    _refresh();
  }

  Future<void> deleteContact(String id) async {
    await _service.deleteContact(id);
    _refresh();
  }

  Future<void> clearAll() async {
    await _service.clearAll();
    _refresh();
  }

  Future<bool> importContacts(File file) async {
    final success = await _service.importContacts(file);
    if (success) _refresh();
    return success;
  }

  void updatePresence(String sipUri, String presenceState, String? activity) {
    _service.updatePresence(sipUri, presenceState, activity);
    _refresh();
  }
}
