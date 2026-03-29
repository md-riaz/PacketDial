import 'package:flutter/material.dart';

class DiagnosticsSectionCard extends StatelessWidget {
  const DiagnosticsSectionCard({
    super.key,
    required this.title,
    required this.lines,
  });

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        title: Text(title),
        subtitle: Text('${lines.length} items'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: lines.isEmpty
            ? const [Text('No entries.')]
            : lines
                  .map(
                    (line) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: SelectableText(line),
                      ),
                    ),
                  )
                  .toList(),
      ),
    );
  }
}
