import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../core/app_theme.dart';
import '../core/app_settings_service.dart';
import '../core/clipboard_service.dart';
import '../core/contacts_service.dart';
import 'diagnostics_screen.dart';
import 'integration_settings_page.dart';
import '../core/engine_channel.dart';

/// Unified app-wide settings page.
class AppSettingsPage extends ConsumerStatefulWidget {
  const AppSettingsPage({super.key});

  @override
  ConsumerState<AppSettingsPage> createState() => _AppSettingsPageState();
}

class _AppSettingsPageState extends ConsumerState<AppSettingsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  // Settings state
  List<Map<String, dynamic>> _codecPriorities = [];
  int _dtmfMethod = 1;
  bool _autoAnswerEnabled = false;
  bool _dndEnabled = false;
  bool _blfEnabled = true;

  // Integration state (loaded but UI not yet implemented)
  // String _ringWebhookUrl = '';
  // String _endWebhookUrl = '';
  // bool _clipboardMonitoringEnabled = false;
  // String _recordingUploadUrl = '';
  // String _recordingFileFieldName = 'recording';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadSettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    // Load from app settings service
    await AppSettingsService.instance.loadSettings();

    setState(() {
      _codecPriorities = AppSettingsService.instance.codecPriorities;
      _dtmfMethod = AppSettingsService.instance.dtmfMethod;
      _autoAnswerEnabled = AppSettingsService.instance.autoAnswerEnabled;
      _dndEnabled = AppSettingsService.instance.dndEnabled;
      _blfEnabled = AppSettingsService.instance.blfEnabled;
      // Integration settings (UI not yet implemented)
      // _ringWebhookUrl = AppSettingsService.instance.ringWebhookUrl;
      // _endWebhookUrl = AppSettingsService.instance.endWebhookUrl;
      // _clipboardMonitoringEnabled =
      //     AppSettingsService.instance.clipboardMonitoringEnabled;
      // _recordingUploadUrl = AppSettingsService.instance.recordingUploadUrl;
      // _recordingFileFieldName =
      //     AppSettingsService.instance.recordingFileFieldName;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D0D1A), Color(0xFF1A1040)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            'Settings',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
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
              Tab(
                  icon: Icon(Icons.integration_instructions),
                  text: 'Integrations'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(AppTheme.primary),
                ),
              )
            : TabBarView(
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
      ),
    );
  }

  Widget _buildGeneralTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Application Settings'),
          const SizedBox(height: 16),

          // App Info Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: const Column(
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

          _buildSectionTitle('Preferences'),
          const SizedBox(height: 16),

          // BLF Toggle
          _buildSettingCard(
            icon: Icons.visibility,
            title: 'BLF / Presence',
            subtitle: 'Show contact presence status',
            trailing: Switch(
              value: _blfEnabled,
              onChanged: (value) async {
                setState(() => _blfEnabled = value);
                await AppSettingsService.instance.setBlfEnabled(value);
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
    final availableCodecs = [
      {'id': 'PCMU', 'name': 'G.711 μ-law (PCMU)'},
      {'id': 'PCMA', 'name': 'G.711 A-law (PCMA)'},
      {'id': 'G729', 'name': 'G.729'},
      {'id': 'G722', 'name': 'G.722 (HD)'},
      {'id': 'OPUS', 'name': 'Opus (HD)'},
      {'id': 'GSM', 'name': 'GSM'},
      {'id': 'iLBC', 'name': 'iLBC'},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Codec Priority'),
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
              setState(() {
                if (newIndex > oldIndex) newIndex--;
                final item = availableCodecs.removeAt(oldIndex);
                availableCodecs.insert(newIndex, item);
                _updateCodecPriorities(availableCodecs);
              });
            },
            itemBuilder: (context, index) {
              final codec = availableCodecs[index];
              final isEnabled = _codecPriorities.any(
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
                      setState(() {
                        if (value) {
                          _codecPriorities.add({
                            'codec': codec['id'],
                            'enabled': true,
                            'priority': 10 - index,
                          });
                        } else {
                          _codecPriorities.removeWhere(
                            (c) => c['codec'] == codec['id'],
                          );
                        }
                        AppSettingsService.instance
                            .setCodecPriorities(_codecPriorities);
                      });
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
          _buildSectionTitle('Call Settings'),
          const SizedBox(height: 16),

          // DND Toggle
          _buildSettingCard(
            icon: Icons.do_not_disturb,
            title: 'Do Not Disturb',
            subtitle: _dndEnabled
                ? 'Enabled - All incoming calls rejected'
                : 'Disabled - Calls ring normally',
            trailing: Switch(
              value: _dndEnabled,
              onChanged: (value) async {
                setState(() => _dndEnabled = value);
                await AppSettingsService.instance.setDndEnabled(value);
              },
              activeThumbColor: AppTheme.errorRed,
            ),
          ),

          const SizedBox(height: 16),

          // Auto Answer
          _buildSettingCard(
            icon: Icons.phone_callback,
            title: 'Auto Answer',
            subtitle: _autoAnswerEnabled
                ? 'Enabled - All calls answered automatically'
                : 'Disabled - Calls ring normally',
            trailing: Switch(
              value: _autoAnswerEnabled,
              onChanged: (value) async {
                setState(() => _autoAnswerEnabled = value);
                await AppSettingsService.instance.setAutoAnswer(value);
              },
              activeThumbColor: AppTheme.callGreen,
            ),
          ),

          const SizedBox(height: 16),

          // DTMF Method
          _buildSettingCard(
            icon: Icons.dialpad,
            title: 'DTMF Method',
            subtitle: _getDtmfMethodName(_dtmfMethod),
            trailing: PopupMenuButton<int>(
              initialValue: _dtmfMethod,
              onSelected: (value) async {
                setState(() => _dtmfMethod = value);
                await AppSettingsService.instance.setDtmfMethod(value);
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
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: AppTheme.primary, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'These settings apply to all accounts. Changes take effect immediately.',
                    style:
                        TextStyle(color: AppTheme.textTertiary, fontSize: 12),
                  ),
                ),
              ],
            ),
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
          _buildSectionTitle('BLF Contacts'),
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
                child: _buildStatCard(
                  Icons.circle,
                  AppTheme.callGreen,
                  ContactsService.instance
                      .getByPresence('Available')
                      .length
                      .toString(),
                  'Available',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  Icons.circle,
                  AppTheme.errorRed,
                  ContactsService.instance
                      .getByPresence('Busy')
                      .length
                      .toString(),
                  'Busy',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  Icons.circle,
                  AppTheme.textTertiary,
                  ContactsService.instance
                      .getByPresence('Unknown')
                      .length
                      .toString(),
                  'Unknown',
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

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppTheme.textPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 16,
      ),
    );
  }

  Widget _buildSettingCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return Card(
      color: AppTheme.surfaceCard,
      child: ListTile(
        leading: Icon(icon, color: AppTheme.primary, size: 28),
        title: Text(
          title,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            color: AppTheme.textTertiary,
            fontSize: 12,
          ),
        ),
        trailing: trailing,
      ),
    );
  }

  Widget _buildStatCard(
      IconData icon, Color color, String count, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            count,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.8),
              fontSize: 11,
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

  void _updateCodecPriorities(List<Map<String, dynamic>> availableCodecs) {
    final updated = <Map<String, dynamic>>[];
    for (var i = 0; i < availableCodecs.length; i++) {
      final codec = availableCodecs[i];
      final existing = _codecPriorities.firstWhere(
        (c) => c['codec'] == codec['id'],
        orElse: () => {'codec': codec['id'], 'enabled': false, 'priority': 0},
      );
      updated.add({
        'codec': codec['id'],
        'enabled': existing['enabled'] ?? false,
        'priority': availableCodecs.length - i,
      });
    }
    _codecPriorities = updated;
    AppSettingsService.instance.setCodecPriorities(updated);
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
          await _loadSettings();
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
              // Reset to defaults
              await AppSettingsService.instance.setCodecPriorities([
                {'codec': 'PCMU', 'priority': 10, 'enabled': true},
                {'codec': 'PCMA', 'priority': 9, 'enabled': true},
                {'codec': 'G729', 'priority': 8, 'enabled': true},
              ]);
              await AppSettingsService.instance.setDtmfMethod(1);
              await AppSettingsService.instance.setAutoAnswer(false);
              await AppSettingsService.instance.setBlfEnabled(true);
              await _loadSettings();

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
          _buildSectionTitle('Audio Devices'),
          const SizedBox(height: 8),
          const Text(
            'Select your preferred microphone and speaker. If your device isn\'t listed, try refreshing.',
            style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
          ),
          const SizedBox(height: 24),

          // Input Device
          _buildSettingCard(
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
          _buildSettingCard(
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
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.lightbulb_outline,
                    color: AppTheme.primary, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'If you experience no sound, ensure your earphones are connected and selected as the default communication device in Windows Sound Settings.',
                    style:
                        TextStyle(color: AppTheme.textTertiary, fontSize: 12),
                  ),
                ),
              ],
            ),
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
          _buildSectionTitle('Integration Features'),
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
          _buildSectionTitle('Quick Toggles'),
          const SizedBox(height: 16),

          // Clipboard monitoring quick toggle
          _buildSettingCard(
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
