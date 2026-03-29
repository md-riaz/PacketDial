class Contact {
  const Contact({
    required this.id,
    required this.name,
    required this.extension,
    this.presence = 'Offline',
    this.notes = '',
    this.isFavorite = false,
  });

  final String id;
  final String name;
  final String extension;
  final String presence;
  final String notes;
  final bool isFavorite;

  Contact copyWith({
    String? id,
    String? name,
    String? extension,
    String? presence,
    String? notes,
    bool? isFavorite,
  }) {
    return Contact(
      id: id ?? this.id,
      name: name ?? this.name,
      extension: extension ?? this.extension,
      presence: presence ?? this.presence,
      notes: notes ?? this.notes,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}
