import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';

import '../widgets/diagnostics_fact_panel.dart';
import '../widgets/diagnostics_log_list.dart';
import '../widgets/diagnostics_section_card.dart';

class DiagnosticsPage extends StatelessWidget {
  const DiagnosticsPage({
    super.key,
    required this.bundle,
    required this.logs,
    required this.onExport,
  });

  final DiagnosticsBundle bundle;
  final List<String> logs;
  final VoidCallback onExport;

  Map<String, List<String>> _derivedSections() {
    return <String, List<String>>{
      ...bundle.sections,
      if (bundle.facts.isNotEmpty)
        'Facts': bundle.facts.entries
            .map((entry) => '${entry.key}: ${entry.value}')
            .toList(),
      if (logs.isNotEmpty) 'Event log': logs,
    };
  }

  @override
  Widget build(BuildContext context) {
    final sections = _derivedSections();

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Diagnostics',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(bundle.summary),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: onExport,
              icon: const Icon(Icons.download_outlined),
              label: const Text('Export diagnostics'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _InfoChip(
              icon: Icons.fact_check_outlined,
              label: '${bundle.facts.length} facts',
            ),
            _InfoChip(
              icon: Icons.list_alt_outlined,
              label: '${logs.length} log lines',
            ),
            if (bundle.lastExportPath != null)
              _InfoChip(
                icon: Icons.folder_open_outlined,
                label: 'Last export available',
              ),
          ],
        ),
        const SizedBox(height: 20),
        DiagnosticsFactPanel(facts: bundle.facts),
        const SizedBox(height: 20),
        if (bundle.lastExportPath != null)
          Card(
            child: ListTile(
              leading: const Icon(Icons.download_done_outlined),
              title: const Text('Last export path'),
              subtitle: SelectableText(bundle.lastExportPath!),
            ),
          ),
        if (bundle.lastExportPath != null) const SizedBox(height: 20),
        ...sections.entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DiagnosticsSectionCard(title: entry.key, lines: entry.value),
          ),
        ),
        const SizedBox(height: 8),
        Text('Event log', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        DiagnosticsLogList(logs: logs),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(avatar: Icon(icon, size: 18), label: Text(label));
  }
}
