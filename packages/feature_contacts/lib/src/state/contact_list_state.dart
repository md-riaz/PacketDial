import 'package:app_core/app_core.dart';

enum ContactSortMode { favoritesFirst, alphabetical }

class ContactListState {
  const ContactListState({
    this.query = '',
    this.favoritesOnly = false,
    this.sortMode = ContactSortMode.favoritesFirst,
  });

  final String query;
  final bool favoritesOnly;
  final ContactSortMode sortMode;

  ContactListState copyWith({
    String? query,
    bool? favoritesOnly,
    ContactSortMode? sortMode,
  }) {
    return ContactListState(
      query: query ?? this.query,
      favoritesOnly: favoritesOnly ?? this.favoritesOnly,
      sortMode: sortMode ?? this.sortMode,
    );
  }

  bool matches(Contact contact) {
    if (favoritesOnly && !contact.isFavorite) {
      return false;
    }

    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) {
      return true;
    }

    return <String>[
      contact.name,
      contact.extension,
      contact.presence,
      contact.notes,
    ].any((value) => value.toLowerCase().contains(needle));
  }

  List<Contact> sort(List<Contact> contacts) {
    final sorted = [...contacts];
    sorted.sort((left, right) {
      if (sortMode == ContactSortMode.favoritesFirst) {
        final favoriteCompare = (right.isFavorite ? 1 : 0).compareTo(
          left.isFavorite ? 1 : 0,
        );
        if (favoriteCompare != 0) {
          return favoriteCompare;
        }
      }
      return left.name.toLowerCase().compareTo(right.name.toLowerCase());
    });
    return sorted;
  }
}
