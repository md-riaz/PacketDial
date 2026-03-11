import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../core/app_theme.dart';
import '../widgets/page_scaffold.dart';
import '../widgets/section_title.dart';
import '../widgets/setting_card.dart';
import '../widgets/stat_badge.dart';
import '../widgets/info_banner.dart';
import '../core/app_settings_service.dart';
import '../core/clipboard_service.dart';
import '../core/contacts_service.dart';
import 'diagnostics_screen.dart';
import 'integration_settings_page.dart';
import '../core/engine_channel.dart';
import '../providers/app_settings_provider.dart';

/// Unified app-wide settings page.
class AppSettingsPage extends ConsumerStatefulWidget {
  const AppSettingsPage({super.key});

  @override
  ConsumerState<AppSettingsPage> createState() => _AppSettingsPageState();
}

class _AppSettingsPageState extends ConsumerState<AppSettingsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Settings',
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: AppTheme.textPrimary),
          onSelected: (value) {
            if (value == 'export') _exportSettings();
            if (value == 'import') _importSettings();
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'export',
              child: Row(
                children: [
                  Icon(Icons.file_download, size: 20),
                  SizedBox(width: 12),
                  Text('Export Settings'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'import',
              child: Row(
                children: [
                  Icon(Icons.file_upload, size: 20),
                  SizedBox(width: 12),
                  Text('Import Settings'),
                ],
              ),
            ),
          ],
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        labelColor: AppTheme.primary,
        unselectedLabelColor: AppTheme.textTertiary,
        indicatorColor: AppTheme.primary,
        tabs: const [
          Tab(icon: Icon(Icons.tune), text: 'General'),
          Tab(icon: Icon(Icons.volume_up), text: 'Audio'),
          Tab(icon: Icon(Icons.audio_file), text: 'Codecs'),
          Tab(icon: Icon(Icons.phone_in_talk), text: 'Calls'),
          Tab(icon: Icon(Icons.contacts), text: 'Contacts'),
          Tab(icon: Icon(Icons.integration_instructions), text: 'Integrations'),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGeneralTab(),
          _buildAudioTab(),
          _buildCodecsTab(),
          _buildCallsTab(),
          _buildContactsTab(),
          _buildIntegrationsTab(),
        ],
      ),
    );
  }

  Widget _buildGeneralTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Application Settings'),
          const SizedBox(height: 16),

          // App Info Card
          const InfoBanner(
            icon: Icons.info_outline,
            text: '',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PacketDial',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Version 1.0.0',
                  style: TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Modern Windows SIP softphone with advanced features',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          const SectionTitle('Preferences'),
          const SizedBox(height: 16),

          // BLF Toggle
          SettingCard(
            icon: Icons.visibility,
            title: 'BLF / Presence',
            subtitle: 'Show contact presence status',
            trailing: Switch(
              value: ref.watch(appSettingsProvider).blfEnabled,
              onChanged: (value) async {
                await ref
                    .read(appSettingsProvider.notifier)
                    .setBlfEnabled(value);
              },
              activeThumbColor: AppTheme.primary,
            ),
          ),

          const SizedBox(height: 16),

          // Reset Settings
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showResetDialog(),
              icon: const Icon(Icons.restore, color: AppTheme.warningAmber),
              label: const Text(
                'Reset to Defaults',
                style: TextStyle(color: AppTheme.warningAmber),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.warningAmber),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Diagnostics
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DiagnosticsScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.bug_report, color: AppTheme.primary),
              label: const Text(
                'Diagnostics & Logs',
                style: TextStyle(color: AppTheme.primary),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.primary),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodecsTab() {
    final stateCodecs = ref.watch(appSettingsProvider).codecPriorities;

    final availableCodecs = [
      {'id': 'PCMU', 'name': 'G.711 μ-law (PCMU)'},
      {'id': 'PCMA', 'name': 'G.711 A-law (PCMA)'},
      {'id': 'G729', 'name': 'G.729'},
      {'id': 'G722', 'name': 'G.722 (HD)'},
      {'id': 'OPUS', 'name': 'Opus (HD)'},
      {'id': 'GSM', 'name': 'GSM'},
      {'id': 'iLBC', 'name': 'iLBC'},
    ];

    // Sort available codecs based on saved priorities
    availableCodecs.sort((a, b) {
      final aSaved = stateCodecs.firstWhere((c) => c['codec'] == a['id'],
          orElse: () => {'priority': 0});
      final bSaved = stateCodecs.firstWhere((c) => c['codec'] == b['id'],
          orElse: () => {'priority': 0});
      final aPriority = aSaved['priority'] as int;
      final bPriority = bSaved['priority'] as int;
      return bPriority.compareTo(aPriority); // Higher priority first
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Codec Priority'),
          const SizedBox(height: 8),
          const Text(
            'Drag to reorder. Higher priority codecs are preferred during call negotiation.',
            style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
          ),
          const SizedBox(height: 24),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: availableCodecs.length,
            onReorder: (oldIndex, newIndex) {
              if (newIndex > oldIndex) newIndex--;
              final item = availableCodecs.removeAt(oldIndex);
              availableCodecs.insert(newIndex, item);

              final updated = <Map<String, dynamic>>[];
              for (var i = 0; i < availableCodecs.length; i++) {
                final codecId = availableCodecs[i]['id'] as String;
                final existing = stateCodecs.firstWhere(
                  (c) => c['codec'] == codecId,
                  orElse: () =>
                      {'codec': codecId, 'enabled': false, 'priority': 0},
                );
                updated.add({
                  'codec': codecId,
                  'enabled': existing['enabled'] ?? false,
                  'priority': availableCodecs.length - i,
                });
              }
              ref
                  .read(appSettingsProvider.notifier)
                  .setCodecPriorities(updated);
            },
            itemBuilder: (context, index) {
              final codec = availableCodecs[index];
              final isEnabled = stateCodecs.any(
                (c) => c['codec'] == codec['id'] && c['enabled'] == true,
              );

              return Card(
                key: ValueKey(codec['id']),
                color: AppTheme.surfaceCard,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: ReorderableDragStartListener(
                    index: index,
                    child: const Icon(Icons.drag_handle,
                        color: AppTheme.textTertiary),
                  ),
                  title: Text(
                    codec['name'] as String,
                    style: const TextStyle(color: AppTheme.textPrimary),
                  ),
                  subtitle: Text(
                    codec['id'] as String,
                    style: const TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                  trailing: Switch(
                    value: isEnabled,
                    onChanged: (value) {
                      final updated =
                          List<Map<String, dynamic>>.from(stateCodecs);
                      final idx =
                          updated.indexWhere((c) => c['codec'] == codec['id']);
                      if (idx >= 0) {
                        updated[idx] = Map<String, dynamic>.from(updated[idx]);
                        updated[idx]['enabled'] = value;
                      } else {
                        updated.add({
                          'codec': codec['id'],
                          'enabled': value,
                          'priority': availableCodecs.length - index,
                        });
                      }
                      ref
                          .read(appSettingsProvider.notifier)
                          .setCodecPriorities(updated);
                    },
                    activeThumbColor: AppTheme.primary,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCallsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Call Settings'),
          const SizedBox(height: 16),

          // DND Toggle
          SettingCard(
            icon: Icons.do_not_disturb,
            title: 'Do Not Disturb',
            subtitle: ref.watch(appSettingsProvider).dndEnabled
                ? 'Enabled - All incoming calls rejected'
                : 'Disabled - Calls ring normally',
            trailing: Switch(
              value: ref.watch(appSettingsProvider).dndEnabled,
              onChanged: (value) async {
                await ref
                    .read(appSettingsProvider.notifier)
                    .setDndEnabled(value);
              },
              activeThumbColor: AppTheme.errorRed,
            ),
          ),

          const SizedBox(height: 16),

          // Auto Answer
          SettingCard(
            icon: Icons.phone_callback,
            title: 'Auto Answer',
            subtitle: ref.watch(appSettingsProvider).autoAnswerEnabled
                ? 'Enabled - All calls answered automatically'
                : 'Disabled - Calls ring normally',
            trailing: Switch(
              value: ref.watch(appSettingsProvider).autoAnswerEnabled,
              onChanged: (value) async {
                await ref
                    .read(appSettingsProvider.notifier)
                    .setAutoAnswer(value);
              },
              activeThumbColor: AppTheme.callGreen,
            ),
          ),

          const SizedBox(height: 16),

          // DTMF Method
          SettingCard(
            icon: Icons.dialpad,
            title: 'DTMF Method',
            subtitle:
                _getDtmfMethodName(ref.watch(appSettingsProvider).dtmfMethod),
            trailing: PopupMenuButton<int>(
              initialValue: ref.watch(appSettingsProvider).dtmfMethod,
              onSelected: (value) async {
                await ref
                    .read(appSettingsProvider.notifier)
                    .setDtmfMethod(value);
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 0, child: Text('In-band')),
                const PopupMenuItem(value: 1, child: Text('RFC2833')),
                const PopupMenuItem(value: 2, child: Text('SIP INFO')),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Info card
          const InfoBanner(
            icon: Icons.info_outline,
            text:
                'These settings apply to all accounts. Changes take effect immediately.',
          ),
        ],
      ),
    );
  }

  Widget _buildContactsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('BLF Contacts'),
          const SizedBox(height: 8),
          Text(
            '${ContactsService.instance.contacts.length} contacts loaded',
            style: const TextStyle(color: AppTheme.textTertiary, fontSize: 12),
          ),

          const SizedBox(height: 24),

          // Contact stats
          Row(
            children: [
              Expanded(
                child: StatBadge.card(
                  icon: Icons.circle,
                  color: AppTheme.callGreen,
                  count: ContactsService.instance
                      .getByPresence('Available')
                      .length
                      .toString(),
                  label: 'Available',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatBadge.card(
                  icon: Icons.circle,
                  color: AppTheme.errorRed,
                  count: ContactsService.instance
                      .getByPresence('Busy')
                      .length
                      .toString(),
                  label: 'Busy',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatBadge.card(
                  icon: Icons.circle,
                  color: AppTheme.textTertiary,
                  count: ContactsService.instance
                      .getByPresence('Unknown')
                      .length
                      .toString(),
                  label: 'Unknown',
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Actions
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/blf-contacts'),
              icon: const Icon(Icons.manage_accounts, color: AppTheme.primary),
              label: const Text(
                'Manage Contacts',
                style: TextStyle(color: AppTheme.primary),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.primary),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getDtmfMethodName(int method) {
    switch (method) {
      case 0:
        return 'In-band Audio';
      case 1:
        return 'RFC2833 (Recommended)';
      case 2:
        return 'SIP INFO';
      default:
        return 'Unknown';
    }
  }

  Future<void> _exportSettings() async {
    try {
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Settings',
        fileName: 'packetdial_settings.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null) {
        final file = File(result);
        final success = await AppSettingsService.instance.exportSettings(file);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(success
                  ? 'Settings exported to ${file.path}'
                  : 'Export failed'),
              backgroundColor: success ? AppTheme.callGreen : AppTheme.errorRed,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to export settings'),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _importSettings() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final success = await AppSettingsService.instance.importSettings(file);

        if (success) {
          await ref.read(appSettingsProvider.notifier).reloadSettings();
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  success ? 'Settings imported successfully' : 'Import failed'),
              backgroundColor: success ? AppTheme.callGreen : AppTheme.errorRed,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to import settings'),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        title: const Text('Reset Settings',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text(
          'Reset all settings to default values?',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(appSettingsProvider.notifier).resetToDefaults();

              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Settings reset to defaults'),
                  backgroundColor: AppTheme.callGreen,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style:
                FilledButton.styleFrom(backgroundColor: AppTheme.warningAmber),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioTab() {
    final channel = EngineChannel.instance;
    final inputDevices = channel.audioDevices.where((d) => d.isInput).toList();
    final outputDevices =
        channel.audioDevices.where((d) => d.isOutput).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Audio Devices'),
          const SizedBox(height: 8),
          const Text(
            'Select your preferred microphone and speaker. If your device isn\'t listed, try refreshing.',
            style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
          ),
          const SizedBox(height: 24),

          // Input Device
          SettingCard(
            icon: Icons.mic,
            title: 'Microphone (Input)',
            subtitle: inputDevices.isEmpty
                ? 'No input devices found'
                : 'Current: ${inputDevices.firstWhere((d) => d.id == channel.selectedInputId, orElse: () => inputDevices.first).name}',
            trailing: inputDevices.isEmpty
                ? const SizedBox.shrink()
                : DropdownButton<int>(
                    value:
                        inputDevices.any((d) => d.id == channel.selectedInputId)
                            ? channel.selectedInputId
                            : inputDevices.first.id,
                    dropdownColor: AppTheme.surfaceCard,
                    underline: const SizedBox(),
                    items: inputDevices.map((d) {
                      return DropdownMenuItem<int>(
                        value: d.id,
                        child: Text(d.name,
                            style: const TextStyle(
                                color: AppTheme.textPrimary, fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        channel.engine
                            .setAudioDevices(value, channel.selectedOutputId);
                        setState(() {});
                      }
                    },
                  ),
          ),

          const SizedBox(height: 16),

          // Output Device
          SettingCard(
            icon: Icons.speaker,
            title: 'Speaker (Output)',
            subtitle: outputDevices.isEmpty
                ? 'No output devices found'
                : 'Current: ${outputDevices.firstWhere((d) => d.id == channel.selectedOutputId, orElse: () => outputDevices.first).name}',
            trailing: outputDevices.isEmpty
                ? const SizedBox.shrink()
                : DropdownButton<int>(
                    value: outputDevices
                            .any((d) => d.id == channel.selectedOutputId)
                        ? channel.selectedOutputId
                        : outputDevices.first.id,
                    dropdownColor: AppTheme.surfaceCard,
                    underline: const SizedBox(),
                    items: outputDevices.map((d) {
                      return DropdownMenuItem<int>(
                        value: d.id,
                        child: Text(d.name,
                            style: const TextStyle(
                                color: AppTheme.textPrimary, fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        channel.engine
                            .setAudioDevices(channel.selectedInputId, value);
                        setState(() {});
                      }
                    },
                  ),
          ),

          const SizedBox(height: 32),

          // Refresh Button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                channel.engine.listAudioDevices();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Refreshing audio devices...'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Device List'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Tip card
          const InfoBanner(
            icon: Icons.lightbulb_outline,
            text:
                'If you experience no sound, ensure your earphones are connected and selected as the default communication device in Windows Sound Settings.',
          ),
        ],
      ),
    );
  }

  Widget _buildIntegrationsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Integration Features'),
          const SizedBox(height: 8),
          const Text(
            'Configure webhooks, CRM lookup, screen pop, and more.',
            style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
          ),
          const SizedBox(height: 24),

          // Main integration settings card
          Card(
            color: AppTheme.surfaceCard,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Advanced Integration Settings',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Configure webhooks, CRM customer lookup, screen pop, '
                    'call recording upload, clipboard monitoring, and dialing rules.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const IntegrationSettingsPage(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.settings),
                      label: const Text('Open Integration Settings'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Quick toggles
          const SectionTitle('Quick Toggles'),
          const SizedBox(height: 16),

          // Clipboard monitoring quick toggle
          SettingCard(
            icon: Icons.content_paste_search,
            title: 'Clipboard Monitoring',
            subtitle: 'Detect phone numbers in clipboard and offer to dial.',
            trailing: Switch(
              value: AppSettingsService.instance.clipboardMonitoringEnabled,
              onChanged: (value) async {
                await AppSettingsService.instance
                    .setClipboardMonitoringEnabled(value);
                if (value) {
                  ClipboardService.instance.startMonitoring();
                } else {
                  ClipboardService.instance.stopMonitoring();
                }
                setState(() {});
              },
              activeThumbColor: AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
