import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../core/app_settings_service.dart';
import '../core/clipboard_service.dart';
import '../core/customer_lookup_service.dart';
import '../core/recording_service.dart';
import '../models/dialing_rule.dart';
import '../models/caller_id_transformation.dart';
import '../core/app_theme.dart';
import '../widgets/section_title.dart';
import '../widgets/info_banner.dart';

/// Integration settings page with tabs for all integration features
class IntegrationSettingsPage extends StatefulWidget {
  const IntegrationSettingsPage({super.key});

  @override
  State<IntegrationSettingsPage> createState() =>
      _IntegrationSettingsPageState();
}

class _IntegrationSettingsPageState extends State<IntegrationSettingsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _settings = AppSettingsService.instance;

  // Controllers for webhooks
  final _ringWebhookController = TextEditingController();
  final _endWebhookController = TextEditingController();

  // Controllers for customer lookup
  final _customerLookupUrlController = TextEditingController();
  final _customerLookupTimeoutController = TextEditingController();

  // Controllers for screen pop
  final _screenPopUrlController = TextEditingController();

  // Controllers for recording upload
  final _localRecordingDirController = TextEditingController();
  final _recordingUploadUrlController = TextEditingController();
  final _recordingFieldNameController = TextEditingController();

  // Controllers for clipboard
  final _clipboardIntervalController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _ringWebhookController.text = _settings.ringWebhookUrl;
    _endWebhookController.text = _settings.endWebhookUrl;
    _customerLookupUrlController.text = _settings.customerLookupUrl;
    _customerLookupTimeoutController.text =
        (_settings.customerLookupTimeoutMs / 1000).toString();
    _screenPopUrlController.text = _settings.screenPopUrl;
    var recordingDir = _settings.localRecordingDirectory.trim();
    if (recordingDir.isEmpty) {
      final defaultDir = await RecordingService.instance.getRecordingsDir();
      recordingDir = defaultDir.path;
      await _settings.setLocalRecordingDirectory(recordingDir);
    }
    _localRecordingDirController.text = recordingDir;
    _recordingUploadUrlController.text = _settings.recordingUploadUrl;
    _recordingFieldNameController.text = _settings.recordingFileFieldName;
    _clipboardIntervalController.text =
        (_settings.clipboardPollIntervalMs / 1000).toString();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _ringWebhookController.dispose();
    _endWebhookController.dispose();
    _customerLookupUrlController.dispose();
    _customerLookupTimeoutController.dispose();
    _screenPopUrlController.dispose();
    _localRecordingDirController.dispose();
    _recordingUploadUrlController.dispose();
    _recordingFieldNameController.dispose();
    _clipboardIntervalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceVariant,
        elevation: 0,
        title: const Text('Integration Settings'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primary,
          tabs: const [
            Tab(icon: Icon(Icons.webhook), text: 'Webhooks'),
            Tab(icon: Icon(Icons.person_search), text: 'CRM Lookup'),
            Tab(icon: Icon(Icons.open_in_browser), text: 'Screen Pop'),
            Tab(icon: Icon(Icons.mic), text: 'Recording'),
            Tab(icon: Icon(Icons.content_paste), text: 'Clipboard'),
            Tab(icon: Icon(Icons.rule), text: 'Dialing Rules'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildWebhooksTab(),
          _buildCrmLookupTab(),
          _buildScreenPopTab(),
          _buildRecordingTab(),
          _buildClipboardTab(),
          _buildDialingRulesTab(),
        ],
      ),
    );
  }

  Widget _buildWebhooksTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SectionTitle('Webhook Configuration'),
        const SizedBox(height: 8),
        const InfoBanner(
          icon: Icons.webhook,
          text:
              'Webhooks are triggered on specific call events. URLs support placeholders: %NUMBER%, %ID%, %DIRECTION%, %DURATION%',
        ),
        const SizedBox(height: 24),

        // Ring Webhook
        SwitchListTile(
          title: const Text('Incoming Call Webhook',
              style: TextStyle(color: AppTheme.textPrimary)),
          subtitle: const Text('Triggered when call starts ringing',
              style: TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
          value: _settings.ringWebhookEnabled,
          activeThumbColor: AppTheme.primary,
          contentPadding: EdgeInsets.zero,
          onChanged: (value) async {
            await _settings.setRingWebhookEnabled(value);
            setState(() {});
          },
        ),
        if (_settings.ringWebhookEnabled) ...[
          const SizedBox(height: 12),
          _buildField(
            controller: _ringWebhookController,
            label: 'Webhook URL',
            hint: 'https://example.com/webhook/ring?number=%NUMBER%',
            icon: Icons.link,
            onSubmitted: (value) async {
              await _settings.setRingWebhookUrl(value);
              _showSavedSnackbar();
            },
          ),
        ],

        const SizedBox(height: 24),

        // Call End Webhook
        SwitchListTile(
          title: const Text('Call End Webhook',
              style: TextStyle(color: AppTheme.textPrimary)),
          subtitle: const Text('Triggered when call ends',
              style: TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
          value: _settings.callEndWebhookEnabled,
          activeThumbColor: AppTheme.primary,
          contentPadding: EdgeInsets.zero,
          onChanged: (value) async {
            await _settings.setCallEndWebhookEnabled(value);
            setState(() {});
          },
        ),
        if (_settings.callEndWebhookEnabled) ...[
          const SizedBox(height: 12),
          _buildField(
            controller: _endWebhookController,
            label: 'Webhook URL',
            hint:
                'https://example.com/webhook/end?number=%NUMBER%&duration=%DURATION%',
            icon: Icons.link,
            onSubmitted: (value) async {
              await _settings.setEndWebhookUrl(value);
              _showSavedSnackbar();
            },
          ),
        ],

        const SizedBox(height: 32),
        _buildSaveButton(() async {
          await _settings.setRingWebhookUrl(_ringWebhookController.text);
          await _settings.setEndWebhookUrl(_endWebhookController.text);
          _showSavedSnackbar();
        }),
      ],
    );
  }

  Widget _buildCrmLookupTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SectionTitle('CRM Customer Lookup'),
        const SizedBox(height: 8),
        const InfoBanner(
          icon: Icons.person_search,
          text:
              'Automatically fetch customer data from your CRM when a call comes in.',
        ),
        const SizedBox(height: 24),
        SwitchListTile(
          title: const Text('Enable Customer Lookup',
              style: TextStyle(color: AppTheme.textPrimary)),
          subtitle: const Text('Fetch customer data on incoming calls',
              style: TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
          value: _settings.customerLookupEnabled,
          activeThumbColor: AppTheme.primary,
          contentPadding: EdgeInsets.zero,
          onChanged: (value) async {
            await _settings.setCustomerLookupEnabled(value);
            setState(() {});
          },
        ),
        const SizedBox(height: 24),
        _buildField(
          controller: _customerLookupUrlController,
          label: 'CRM Web Service URL',
          hint: 'https://crm.example.com/lookup?number=%NUMBER%',
          icon: Icons.link,
        ),
        const SizedBox(height: 18),
        _buildField(
          controller: _customerLookupTimeoutController,
          label: 'Timeout (seconds)',
          hint: '5',
          icon: Icons.timer_outlined,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        const SizedBox(height: 24),
        _buildSaveButton(() async {
          await _settings
              .setCustomerLookupUrl(_customerLookupUrlController.text);
          final timeoutSec =
              int.tryParse(_customerLookupTimeoutController.text) ?? 5;
          await _settings.setCustomerLookupTimeoutMs(timeoutSec * 1000);
          _showSavedSnackbar();
        }),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              CustomerLookupService.instance.clearCache();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Customer lookup cache cleared')),
              );
            },
            icon:
                const Icon(Icons.delete_outline, color: AppTheme.textTertiary),
            label: const Text('Clear Cache',
                style: TextStyle(color: AppTheme.textTertiary)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.border),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScreenPopTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SectionTitle('Screen Pop Configuration'),
        const SizedBox(height: 8),
        const InfoBanner(
          icon: Icons.open_in_browser,
          text:
              'Open a CRM page or trigger a webhook when calls come in. Supports browser launch or background HTTP request.',
        ),
        const SizedBox(height: 12),
        InfoBanner(
          icon: Icons.code,
          color: AppTheme.accent,
          text: '',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Supported placeholders',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                      fontSize: 13)),
              const SizedBox(height: 6),
              Text(
                '%NUMBER%, %NAME%, %COMPANY%, %EXTID%, %DID%, %ID%, %ACCOUNT_ID%, %STATE%, %DIRECTION%, %CONTACT_LINK%',
                style: TextStyle(
                    color: AppTheme.textSecondary.withValues(alpha: 0.8),
                    fontSize: 11,
                    fontFamily: 'monospace'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildField(
          controller: _screenPopUrlController,
          label: 'Screen Pop URL',
          hint: 'https://portal.example.com/callcenter.php?phone=%NUMBER%',
          icon: Icons.link,
        ),
        const SizedBox(height: 18),
        DropdownButtonFormField<String>(
          initialValue: _settings.screenPopEvent,
          decoration: InputDecoration(
            labelText: 'Trigger Event',
            contentPadding:
                const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            labelStyle:
                const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              borderSide: const BorderSide(color: AppTheme.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              borderSide: const BorderSide(color: AppTheme.primary, width: 2),
            ),
          ),
          dropdownColor: AppTheme.surfaceVariant,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
          items: const [
            DropdownMenuItem(value: 'ring', child: Text('Incoming Call Ring')),
            DropdownMenuItem(value: 'answer', child: Text('Call Answered')),
            DropdownMenuItem(value: 'end', child: Text('Call Ended')),
          ],
          onChanged: (value) async {
            if (value != null) {
              await _settings.setScreenPopEvent(value);
            }
          },
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('Open in Browser',
              style: TextStyle(color: AppTheme.textPrimary)),
          subtitle: const Text('If off, send background HTTP request',
              style: TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
          value: _settings.screenPopOpenBrowser,
          activeThumbColor: AppTheme.primary,
          contentPadding: EdgeInsets.zero,
          onChanged: (value) async {
            await _settings.setScreenPopOpenBrowser(value);
            setState(() {});
          },
        ),
        SwitchListTile(
          title: const Text('Suppress Main Window',
              style: TextStyle(color: AppTheme.textPrimary)),
          subtitle: const Text('Don\'t show PacketDial window on screen pop',
              style: TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
          value: _settings.screenPopSuppressWindow,
          activeThumbColor: AppTheme.primary,
          contentPadding: EdgeInsets.zero,
          onChanged: (value) async {
            await _settings.setScreenPopSuppressWindow(value);
            setState(() {});
          },
        ),
        const SizedBox(height: 24),
        _buildSaveButton(() async {
          await _settings.setScreenPopUrl(_screenPopUrlController.text);
          _showSavedSnackbar();
        }),
      ],
    );
  }

  Widget _buildRecordingTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SectionTitle('Local Call Recording'),
        const SizedBox(height: 8),
        const InfoBanner(
          icon: Icons.mic,
          text:
              'Record all calls locally. Saved as WAV files in the app recordings folder.',
        ),
        const SizedBox(height: 24),
        SwitchListTile(
          title: const Text('Enable Local Call Recording',
              style: TextStyle(color: AppTheme.textPrimary)),
          subtitle: const Text('Auto-record every active call',
              style: TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
          value: _settings.localCallRecordingEnabled,
          activeThumbColor: AppTheme.primary,
          contentPadding: EdgeInsets.zero,
          onChanged: (value) async {
            if (value && _localRecordingDirController.text.trim().isEmpty) {
              final defaultDir =
                  await RecordingService.instance.getRecordingsDir();
              _localRecordingDirController.text = defaultDir.path;
              await _settings.setLocalRecordingDirectory(defaultDir.path);
            }
            await _settings.setLocalCallRecordingEnabled(value);
            setState(() {});
          },
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildField(
                controller: _localRecordingDirController,
                label: 'Recording Folder',
                hint: r'C:\Recordings\PacketDial',
                icon: Icons.folder_outlined,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: () async {
                  final result = await FilePicker.platform.getDirectoryPath(
                    dialogTitle: 'Select Recording Folder',
                  );
                  if (result != null) {
                    _localRecordingDirController.text = result;
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.surfaceCard,
                  foregroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                ),
                child: const Icon(Icons.folder_open, size: 20),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        DropdownButtonFormField<String>(
          initialValue: _settings.localRecordingFormat,
          decoration: InputDecoration(
            labelText: 'Recording Format',
            contentPadding:
                const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            labelStyle:
                const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              borderSide: const BorderSide(color: AppTheme.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              borderSide: const BorderSide(color: AppTheme.primary, width: 2),
            ),
          ),
          dropdownColor: AppTheme.surfaceVariant,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
          items: const [
            DropdownMenuItem(value: 'wav', child: Text('WAV')),
            DropdownMenuItem(value: 'mp3', child: Text('MP3')),
          ],
          onChanged: (value) async {
            if (value == null) return;
            await _settings.setLocalRecordingFormat(value);
          },
        ),
        const SizedBox(height: 32),
        const SectionTitle('Recording Upload'),
        const SizedBox(height: 8),
        const InfoBanner(
          icon: Icons.cloud_upload_outlined,
          text:
              'Automatically upload call recordings to your server via HTTP POST.',
        ),
        const SizedBox(height: 24),
        SwitchListTile(
          title: const Text('Enable Recording Upload',
              style: TextStyle(color: AppTheme.textPrimary)),
          subtitle: const Text('Upload recordings after calls end',
              style: TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
          value: _settings.recordingUploadEnabled,
          activeThumbColor: AppTheme.primary,
          contentPadding: EdgeInsets.zero,
          onChanged: (value) async {
            await _settings.setRecordingUploadEnabled(value);
            setState(() {});
          },
        ),
        const SizedBox(height: 18),
        _buildField(
          controller: _recordingUploadUrlController,
          label: 'Upload URL',
          hint: 'https://example.com/upload-recording',
          icon: Icons.link,
        ),
        const SizedBox(height: 18),
        _buildField(
          controller: _recordingFieldNameController,
          label: 'File Field Name',
          hint: 'recording',
          icon: Icons.text_fields,
        ),
        const SizedBox(height: 24),
        _buildSaveButton(() async {
          await _settings
              .setLocalRecordingDirectory(_localRecordingDirController.text);
          await _settings
              .setRecordingUploadUrl(_recordingUploadUrlController.text);
          await _settings
              .setRecordingFileFieldName(_recordingFieldNameController.text);
          _showSavedSnackbar();
        }),
      ],
    );
  }

  Widget _buildClipboardTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SectionTitle('Clipboard Monitoring'),
        const SizedBox(height: 8),
        const InfoBanner(
          icon: Icons.content_paste_search,
          text:
              'Automatically detect phone numbers copied to clipboard. A popup will appear to confirm dialing.',
        ),
        const SizedBox(height: 24),
        SwitchListTile(
          title: const Text('Enable Clipboard Monitoring',
              style: TextStyle(color: AppTheme.textPrimary)),
          subtitle: const Text('Watch clipboard for phone numbers',
              style: TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
          value: _settings.clipboardMonitoringEnabled,
          activeThumbColor: AppTheme.primary,
          contentPadding: EdgeInsets.zero,
          onChanged: (value) async {
            await _settings.setClipboardMonitoringEnabled(value);
            if (value) {
              ClipboardService.instance.startMonitoring();
            } else {
              ClipboardService.instance.stopMonitoring();
            }
            setState(() {});
          },
        ),
        const SizedBox(height: 18),
        _buildField(
          controller: _clipboardIntervalController,
          label: 'Polling Interval (seconds)',
          hint: '1',
          icon: Icons.timer_outlined,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        const SizedBox(height: 24),
        _buildSaveButton(() async {
          final intervalSec =
              int.tryParse(_clipboardIntervalController.text) ?? 1;
          await _settings.setClipboardPollIntervalMs(intervalSec * 1000);
          _showSavedSnackbar();
        }),
      ],
    );
  }

  Widget _buildDialingRulesTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SectionTitle('Dialing Rules'),
        const SizedBox(height: 8),
        const InfoBanner(
          icon: Icons.rule,
          text:
              'Transform phone numbers before dialing. Rules are applied in priority order (highest first).',
        ),
        const SizedBox(height: 16),

        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _showAddRuleDialog(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Dialing Rule'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // List existing rules
        ..._settings.dialingRules.map((rule) => _buildRuleTile(rule)),

        const SizedBox(height: 32),
        const SectionTitle('Caller ID Transformations'),
        const SizedBox(height: 8),
        const InfoBanner(
          icon: Icons.transform,
          text:
              'Transform incoming caller ID using regex. Useful for normalizing different number formats.',
        ),
        const SizedBox(height: 16),

        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _showAddTransformationDialog(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Transformation'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // List existing transformations
        ..._settings.callerIdTransformations
            .map((t) => _buildTransformationTile(t)),
      ],
    );
  }

  Widget _buildRuleTile(DialingRule rule) {
    return Card(
      child: ListTile(
        title: Text(rule.name),
        subtitle: Text('Pattern: ${rule.pattern}\n→ ${rule.replacement}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: rule.enabled,
              onChanged: (value) async {
                await _settings
                    .updateDialingRule(rule.copyWith(enabled: value));
                setState(() {});
              },
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _showEditRuleDialog(rule),
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _confirmDeleteRule(rule),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransformationTile(CallerIdTransformation t) {
    return Card(
      child: ListTile(
        title: Text(t.name),
        subtitle: Text('Pattern: ${t.pattern}\n→ ${t.replacement}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: t.enabled,
              onChanged: (value) async {
                await _settings
                    .updateCallerIdTransformation(t.copyWith(enabled: value));
                setState(() {});
              },
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _showEditTransformationDialog(t),
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _confirmDeleteTransformation(t),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddRuleDialog() {
    final nameController = TextEditingController();
    final patternController = TextEditingController();
    final replacementController = TextEditingController();
    final priorityController = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Dialing Rule'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: patternController,
                decoration: const InputDecoration(
                  labelText: 'Pattern (Regex)',
                  hintText: r'^\+1(\d{10})$',
                ),
              ),
              TextField(
                controller: replacementController,
                decoration: const InputDecoration(
                  labelText: 'Replacement',
                  hintText: r'001\1',
                ),
              ),
              TextField(
                controller: priorityController,
                decoration: const InputDecoration(labelText: 'Priority'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final rule = DialingRule(
                name: nameController.text,
                pattern: patternController.text,
                replacement: replacementController.text,
                priority: int.tryParse(priorityController.text) ?? 0,
              );
              await _settings.addDialingRule(rule);
              if (!context.mounted || !mounted) return;
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditRuleDialog(DialingRule rule) {
    final nameController = TextEditingController(text: rule.name);
    final patternController = TextEditingController(text: rule.pattern);
    final replacementController = TextEditingController(text: rule.replacement);
    final priorityController =
        TextEditingController(text: rule.priority.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Dialing Rule'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: patternController,
                decoration: const InputDecoration(
                  labelText: 'Pattern (Regex)',
                ),
              ),
              TextField(
                controller: replacementController,
                decoration: const InputDecoration(
                  labelText: 'Replacement',
                ),
              ),
              TextField(
                controller: priorityController,
                decoration: const InputDecoration(labelText: 'Priority'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final updated = rule.copyWith(
                name: nameController.text,
                pattern: patternController.text,
                replacement: replacementController.text,
                priority: int.tryParse(priorityController.text) ?? 0,
              );
              await _settings.updateDialingRule(updated);
              if (!context.mounted || !mounted) return;
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteRule(DialingRule rule) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Rule'),
        content: Text('Delete "${rule.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _settings.removeDialingRule(rule.id);
              if (!context.mounted || !mounted) return;
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddTransformationDialog() {
    final nameController = TextEditingController();
    final patternController = TextEditingController();
    final replacementController = TextEditingController();
    final priorityController = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Caller ID Transformation'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: patternController,
                decoration: const InputDecoration(
                  labelText: 'Pattern (Regex)',
                ),
              ),
              TextField(
                controller: replacementController,
                decoration: const InputDecoration(
                  labelText: 'Replacement',
                ),
              ),
              TextField(
                controller: priorityController,
                decoration: const InputDecoration(labelText: 'Priority'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final transformation = CallerIdTransformation(
                name: nameController.text,
                pattern: patternController.text,
                replacement: replacementController.text,
                priority: int.tryParse(priorityController.text) ?? 0,
              );
              await _settings.addCallerIdTransformation(transformation);
              if (!context.mounted || !mounted) return;
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditTransformationDialog(CallerIdTransformation t) {
    final nameController = TextEditingController(text: t.name);
    final patternController = TextEditingController(text: t.pattern);
    final replacementController = TextEditingController(text: t.replacement);
    final priorityController =
        TextEditingController(text: t.priority.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Transformation'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: patternController,
                decoration: const InputDecoration(
                  labelText: 'Pattern (Regex)',
                ),
              ),
              TextField(
                controller: replacementController,
                decoration: const InputDecoration(
                  labelText: 'Replacement',
                ),
              ),
              TextField(
                controller: priorityController,
                decoration: const InputDecoration(labelText: 'Priority'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final updated = t.copyWith(
                name: nameController.text,
                pattern: patternController.text,
                replacement: replacementController.text,
                priority: int.tryParse(priorityController.text) ?? 0,
              );
              await _settings.updateCallerIdTransformation(updated);
              if (!context.mounted || !mounted) return;
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteTransformation(CallerIdTransformation t) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transformation'),
        content: Text('Delete "${t.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _settings.removeCallerIdTransformation(t.id);
              if (!context.mounted || !mounted) return;
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon, size: 18) : null,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        labelStyle:
            const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        hintStyle: const TextStyle(color: AppTheme.textTertiary, fontSize: 13),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: const BorderSide(color: AppTheme.primary, width: 2),
        ),
      ),
    );
  }

  Widget _buildSaveButton(VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.save, size: 18),
        label: const Text('Save Settings'),
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.primary,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
        ),
      ),
    );
  }

  void _showSavedSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings saved'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
