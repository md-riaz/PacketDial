import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_settings_service.dart';
import '../core/clipboard_service.dart';
import '../core/customer_lookup_service.dart';
import '../core/recording_service.dart';
import '../models/dialing_rule.dart';
import '../models/caller_id_transformation.dart';
import '../core/app_theme.dart';

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
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionTitle('Webhook Configuration'),
        _buildInfoCard(
          'Webhooks are triggered on specific call events.',
          'URLs support placeholders: %NUMBER%, %ID%, %DIRECTION%, %DURATION%',
        ),
        const SizedBox(height: 24),

        // Ring Webhook
        SwitchListTile(
          title: const Text('Incoming Call Webhook'),
          subtitle: const Text('Triggered when call starts ringing'),
          value: _settings.ringWebhookEnabled,
          onChanged: (value) async {
            await _settings.setRingWebhookEnabled(value);
            setState(() {});
          },
        ),
        if (_settings.ringWebhookEnabled)
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
            child: TextField(
              controller: _ringWebhookController,
              decoration: const InputDecoration(
                labelText: 'Webhook URL',
                hintText: 'https://example.com/webhook/ring?number=%NUMBER%',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (value) async {
                await _settings.setRingWebhookUrl(value);
                _showSavedSnackbar();
              },
            ),
          ),

        const Divider(height: 32),

        // Call End Webhook
        SwitchListTile(
          title: const Text('Call End Webhook'),
          subtitle: const Text('Triggered when call ends'),
          value: _settings.callEndWebhookEnabled,
          onChanged: (value) async {
            await _settings.setCallEndWebhookEnabled(value);
            setState(() {});
          },
        ),
        if (_settings.callEndWebhookEnabled)
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
            child: TextField(
              controller: _endWebhookController,
              decoration: const InputDecoration(
                labelText: 'Webhook URL',
                hintText:
                    'https://example.com/webhook/end?number=%NUMBER%&duration=%DURATION%',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (value) async {
                await _settings.setEndWebhookUrl(value);
                _showSavedSnackbar();
              },
            ),
          ),

        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: () async {
            await _settings.setRingWebhookUrl(_ringWebhookController.text);
            await _settings.setEndWebhookUrl(_endWebhookController.text);
            _showSavedSnackbar();
          },
          icon: const Icon(Icons.save),
          label: const Text('Save Settings'),
        ),
      ],
    );
  }

  Widget _buildCrmLookupTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionTitle('CRM Customer Lookup'),
        _buildInfoCard(
          'Automatically fetch customer data from your CRM when a call comes in.',
          'Response format: {"crm_info": {"contact_name": "John", "company": "ACME", "contact_link": "https://..."}}',
        ),
        const SizedBox(height: 24),
        SwitchListTile(
          title: const Text('Enable Customer Lookup'),
          subtitle: const Text('Fetch customer data on incoming calls'),
          value: _settings.customerLookupEnabled,
          onChanged: (value) async {
            await _settings.setCustomerLookupEnabled(value);
            setState(() {});
          },
        ),
        const Divider(height: 32),
        const ListTile(
          title: Text('Lookup URL'),
          subtitle: Text('Use %NUMBER% and %EXTID% placeholders'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _customerLookupUrlController,
            decoration: const InputDecoration(
              labelText: 'CRM Web Service URL',
              hintText: 'https://crm.example.com/lookup?number=%NUMBER%',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const ListTile(
          title: Text('Timeout'),
          subtitle: Text('Maximum time to wait for response'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _customerLookupTimeoutController,
            decoration: const InputDecoration(
              labelText: 'Timeout (seconds)',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () async {
            await _settings
                .setCustomerLookupUrl(_customerLookupUrlController.text);
            final timeoutSec =
                int.tryParse(_customerLookupTimeoutController.text) ?? 5;
            await _settings.setCustomerLookupTimeoutMs(timeoutSec * 1000);
            _showSavedSnackbar();
          },
          icon: const Icon(Icons.save),
          label: const Text('Save Settings'),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () {
            CustomerLookupService.instance.clearCache();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Customer lookup cache cleared')),
            );
          },
          icon: const Icon(Icons.delete_outline),
          label: const Text('Clear Cache'),
        ),
      ],
    );
  }

  Widget _buildScreenPopTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionTitle('Screen Pop Configuration'),
        _buildInfoCard(
          'Open a CRM page or trigger a webhook when calls come in.',
          'Supports browser launch or background HTTP request. Use placeholders in URL query params.',
        ),
        const SizedBox(height: 12),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Supported placeholders',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '%NUMBER%, %NAME%, %COMPANY%, %EXTID%, %DID%, %ID%, %ACCOUNT_ID%, %STATE%, %DIRECTION%, %CONTACT_LINK%',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Example: https://portal.example.com/callcenter.php?apikey=YOUR_API_KEY&phone=%NUMBER%',
                  style: TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const ListTile(
          title: Text('Screen Pop URL'),
          subtitle: Text('URL to open on incoming calls'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _screenPopUrlController,
            decoration: const InputDecoration(
              labelText: 'URL',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const ListTile(
          title: Text('Trigger Event'),
          subtitle: Text('When to trigger screen pop'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DropdownButtonFormField<String>(
            initialValue: _settings.screenPopEvent,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                  value: 'ring', child: Text('Incoming Call Ring')),
              DropdownMenuItem(value: 'answer', child: Text('Call Answered')),
              DropdownMenuItem(value: 'end', child: Text('Call Ended')),
            ],
            onChanged: (value) async {
              if (value != null) {
                await _settings.setScreenPopEvent(value);
              }
            },
          ),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          title: const Text('Open in Browser'),
          subtitle: const Text('If off, send background HTTP request'),
          value: _settings.screenPopOpenBrowser,
          onChanged: (value) async {
            await _settings.setScreenPopOpenBrowser(value);
            setState(() {});
          },
        ),
        SwitchListTile(
          title: const Text('Suppress Main Window'),
          subtitle: const Text('Don\'t show PacketDial window on screen pop'),
          value: _settings.screenPopSuppressWindow,
          onChanged: (value) async {
            await _settings.setScreenPopSuppressWindow(value);
            setState(() {});
          },
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () async {
            await _settings.setScreenPopUrl(_screenPopUrlController.text);
            _showSavedSnackbar();
          },
          icon: const Icon(Icons.save),
          label: const Text('Save Settings'),
        ),
      ],
    );
  }

  Widget _buildRecordingTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionTitle('Local Call Recording'),
        _buildInfoCard(
          'Record all calls locally for all accounts when enabled.',
          'Saved as WAV files in the app recordings folder.',
        ),
        const SizedBox(height: 24),
        SwitchListTile(
          title: const Text('Enable Local Call Recording'),
          subtitle: const Text('Auto-record every active call'),
          value: _settings.localCallRecordingEnabled,
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
        const ListTile(
          title: Text('Recording Folder'),
          subtitle: Text('Local path where call recordings are saved'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _localRecordingDirController,
            decoration: const InputDecoration(
              labelText: 'Folder Path',
              helperText: 'Defaults to app Documents/recordings folder.',
              hintText: r'C:\Recordings\PacketDial',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const ListTile(
          title: Text('Recording Format'),
          subtitle: Text('File format for new local recordings'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DropdownButtonFormField<String>(
            initialValue: _settings.localRecordingFormat,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'wav', child: Text('WAV')),
              DropdownMenuItem(value: 'mp3', child: Text('MP3')),
            ],
            onChanged: (value) async {
              if (value == null) return;
              await _settings.setLocalRecordingFormat(value);
            },
          ),
        ),
        const Divider(height: 32),
        _buildSectionTitle('Recording Upload'),
        _buildInfoCard(
          'Automatically upload call recordings to your server.',
          'Uses HTTP POST with multipart/form-data.',
        ),
        const SizedBox(height: 24),
        SwitchListTile(
          title: const Text('Enable Recording Upload'),
          subtitle: const Text('Upload recordings after calls end'),
          value: _settings.recordingUploadEnabled,
          onChanged: (value) async {
            await _settings.setRecordingUploadEnabled(value);
            setState(() {});
          },
        ),
        const Divider(height: 32),
        const ListTile(
          title: Text('Upload URL'),
          subtitle: Text('Endpoint to receive recording files'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _recordingUploadUrlController,
            decoration: const InputDecoration(
              labelText: 'Upload URL',
              hintText: 'https://example.com/upload-recording',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const ListTile(
          title: Text('File Field Name'),
          subtitle: Text('HTML input field name for the file'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _recordingFieldNameController,
            decoration: const InputDecoration(
              labelText: 'Field Name',
              hintText: 'recording',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () async {
            await _settings
                .setLocalRecordingDirectory(_localRecordingDirController.text);
            await _settings
                .setRecordingUploadUrl(_recordingUploadUrlController.text);
            await _settings
                .setRecordingFileFieldName(_recordingFieldNameController.text);
            _showSavedSnackbar();
          },
          icon: const Icon(Icons.save),
          label: const Text('Save Settings'),
        ),
      ],
    );
  }

  Widget _buildClipboardTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionTitle('Clipboard Monitoring'),
        _buildInfoCard(
          'Automatically detect phone numbers copied to clipboard.',
          'A popup will appear to confirm dialing.',
        ),
        const SizedBox(height: 24),
        SwitchListTile(
          title: const Text('Enable Clipboard Monitoring'),
          subtitle: const Text('Watch clipboard for phone numbers'),
          value: _settings.clipboardMonitoringEnabled,
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
        const Divider(height: 32),
        const ListTile(
          title: Text('Polling Interval'),
          subtitle: Text('How often to check clipboard'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _clipboardIntervalController,
            decoration: const InputDecoration(
              labelText: 'Interval (seconds)',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () async {
            final intervalSec =
                int.tryParse(_clipboardIntervalController.text) ?? 1;
            await _settings.setClipboardPollIntervalMs(intervalSec * 1000);
            _showSavedSnackbar();
          },
          icon: const Icon(Icons.save),
          label: const Text('Save Settings'),
        ),
      ],
    );
  }

  Widget _buildDialingRulesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionTitle('Dialing Rules'),
        _buildInfoCard(
          'Transform phone numbers before dialing.',
          'Rules are applied in priority order (highest first).',
        ),
        const SizedBox(height: 16),

        ElevatedButton.icon(
          onPressed: () => _showAddRuleDialog(),
          icon: const Icon(Icons.add),
          label: const Text('Add Dialing Rule'),
        ),

        const SizedBox(height: 16),

        // List existing rules
        ..._settings.dialingRules.map((rule) => _buildRuleTile(rule)),

        const SizedBox(height: 32),
        _buildSectionTitle('Caller ID Transformations'),
        _buildInfoCard(
          'Transform incoming caller ID using regex.',
          'Useful for normalizing different number formats.',
        ),
        const SizedBox(height: 16),

        ElevatedButton.icon(
          onPressed: () => _showAddTransformationDialog(),
          icon: const Icon(Icons.add),
          label: const Text('Add Transformation'),
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

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
    );
  }

  Widget _buildInfoCard(String title, String subtitle) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
          ],
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
