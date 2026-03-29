import '../models/contact.dart';

class ContactRepository {
  const ContactRepository();

  List<Contact> ensureSeeded(List<Contact> contacts) {
    if (contacts.isNotEmpty) {
      return contacts;
    }

    return const <Contact>[
      Contact(id: 'c1', name: 'Sales', extension: '2001', presence: 'Idle'),
      Contact(id: 'c2', name: 'Support', extension: '2002', presence: 'Busy'),
      Contact(
        id: 'c3',
        name: 'Warehouse',
        extension: '2010',
        presence: 'Ringing',
      ),
    ];
  }
}
