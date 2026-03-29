import 'package:flutter/material.dart';

class DiagnosticsLogList extends StatelessWidget {
  const DiagnosticsLogList({super.key, required this.logs});

  final List<String> logs;

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No log lines recorded yet.'),
        ),
      );
    }

    return Column(
      children: logs
          .map(
            (line) => Card(
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.article_outlined),
                title: SelectableText(line),
              ),
            ),
          )
          .toList(),
    );
  }
}
