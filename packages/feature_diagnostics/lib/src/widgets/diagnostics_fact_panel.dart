import 'package:flutter/material.dart';

class DiagnosticsFactPanel extends StatelessWidget {
  const DiagnosticsFactPanel({super.key, required this.facts});

  final Map<String, String> facts;

  @override
  Widget build(BuildContext context) {
    if (facts.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No diagnostic facts are available yet.'),
        ),
      );
    }

    final isNarrow = MediaQuery.sizeOf(context).width < 700;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 16,
          runSpacing: 12,
          children: facts.entries
              .map(
                (entry) => SizedBox(
                  width: isNarrow ? double.infinity : 240,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.key,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(entry.value),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
