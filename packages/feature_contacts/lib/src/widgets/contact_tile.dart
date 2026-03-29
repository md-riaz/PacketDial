import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';

class ContactTile extends StatelessWidget {
  const ContactTile({
    super.key,
    required this.contact,
    required this.onDial,
    required this.onToggleFavorite,
    required this.onEdit,
    required this.onDelete,
  });

  final Contact contact;
  final VoidCallback onDial;
  final VoidCallback onToggleFavorite;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trimmedName = contact.name.trim();
    final initial = trimmedName.isEmpty ? '?' : trimmedName[0].toUpperCase();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: contact.isFavorite
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.secondaryContainer,
              child: Text(initial),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          contact.name,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      if (contact.isFavorite)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Icon(
                            Icons.star_rounded,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ext ${contact.extension} - ${contact.presence}',
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (contact.notes.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      contact.notes,
                      style: theme.textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Wrap(
              spacing: 8,
              children: [
                IconButton(
                  tooltip: 'Favorite',
                  onPressed: onToggleFavorite,
                  icon: Icon(
                    contact.isFavorite
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                  ),
                ),
                IconButton(
                  tooltip: 'Edit',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Delete',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
                FilledButton.tonalIcon(
                  onPressed: onDial,
                  icon: const Icon(Icons.call_outlined),
                  label: const Text('Dial'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
