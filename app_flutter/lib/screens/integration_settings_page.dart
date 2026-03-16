import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_settings_service.dart';
import '../core/customer_lookup_service.dart';
import '../core/recording_service.dart';
import '../core/app_theme.dart';
import '../widgets/section_title.dart';
import '../widgets/info_banner.dart';

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

  final _ringWebhookController = TextEditingController();
  final _endWebhookController = TextEditingController();
  final _customerLookupUrlController = TextEditingController();
  final _customerLookupTimeoutController = TextEditingController();
  final _screenPopUrlController = TextEditingController();
  final _localRecordingDirController = TextEditingController();
  final _recordingUploadUrlController = TextEditingController();
  final _recordingFieldNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
    if (mounted) setState(() {});
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Integration Settings'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.webhook), text: 'Webhooks'),
            Tab(icon: Icon(Icons.person_search), text: 'CRM Lookup'),
            Tab(icon: Icon(Icons.open_in_browser), text: 'Screen Pop'),
            Tab(icon: Icon(Icons.mic), text: 'Recording'),
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
        ],
      ),
    );
  }

  Widget _buildWebhooksTab() {
    final c = context.colors;
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
        SwitchListTile(
          title: Text('Incoming Call Webhook',
              style: TextStyle(color: c.textPrimary)),
          subtitle: Text('Triggered when call starts ringing',
              style: TextStyle(color: c.textTertiary, fontSize: 12)),
          value: _settings.ringWebhookEnabled,
          activeThumbColor: c.primary,
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
        SwitchListTile(
          title: Text('Call End Webhook',
              style: TextStyle(color: c.textPrimary)),
          subtitle: Text('Triggered when call ends',
              style: TextStyle(color: c.textTertiary, fontSize: 12)),
          value: _settings.callEndWebhookEnabled,
          activeThumbColor: c.primary,
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
    final c = context.colors;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SectionTitle('CRM Customer Lookup'),
        const SizedBox(height: 8),
        const InfoBanner(
          icon: Icons.person_search,
          text:
              'When a call comes in, PacketDial sends an HTTP GET request to your web service with the caller\'s number. Your service returns contact details that appear on the incoming call screen.',
        ),
        const SizedBox(height: 16),
        InfoBanner(
          icon: Icons.help_outline,
          color: context.colors.accent,
          text: '',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('How it works',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                      fontSize: 13)),
              const SizedBox(height: 8),
              Text(
                '1. Incoming call arrives with caller number e.g. +441234567890\n'
                '2. PacketDial calls your URL with %NUMBER% replaced by that number\n'
                '3. Your service looks up the number in your database or CRM\n'
                '4. Your service returns a JSON response (see format below)\n'
                '5. The caller\'s name and company appear on the incoming call screen\n'
                '6. An "Open CRM Record" button appears if you include a contact_link',
                style: TextStyle(
                    color: c.textSecondary, fontSize: 12, height: 1.6),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        InfoBanner(
          icon: Icons.code,
          color: context.colors.accent,
          text: '',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Required JSON response format',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                      fontSize: 13)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '{\n'
                  '  "crm_info": {\n'
                  '    "number": "+441234567890",\n'
                  '    "contact_name": "Jane Smith",\n'
                  '    "company": "Acme Ltd",\n'
                  '    "contact_link": "https://crm.example.com/contacts/42"\n'
                  '  },\n'
                  '  "custom_fields": {\n'
                  '    "account_tier": "Gold",\n'
                  '    "open_tickets": 3\n'
                  '  }\n'
                  '}',
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 11,
                    fontFamily: 'monospace',
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Only crm_info is required. All fields inside it are optional — include only what you have. '
                'contact_link enables the "Open CRM Record" button on the call screen. '
                'custom_fields can hold any extra data you want to pass through.',
                style: TextStyle(
                    color: c.textTertiary, fontSize: 11, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        InfoBanner(
          icon: Icons.swap_horiz,
          color: context.colors.accent,
          text: '',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('URL placeholders',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                      fontSize: 13)),
              const SizedBox(height: 8),
              _buildPlaceholderRow('%NUMBER%',
                  'Caller\'s phone number (after dialing rules applied)'),
              _buildPlaceholderRow('%EXTID%',
                  'Extension ID from the SIP INVITE header, if present'),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SwitchListTile(
          title: Text('Enable Customer Lookup',
              style: TextStyle(color: c.textPrimary)),
          subtitle: Text('Fetch customer data on incoming calls',
              style: TextStyle(color: c.textTertiary, fontSize: 12)),
          value: _settings.customerLookupEnabled,
          activeThumbColor: c.primary,
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
        const SizedBox(height: 8),
        Text(
          'If your CRM takes longer than this to respond, the call screen shows without contact info. '
          'The lookup still completes in the background and updates the screen when it arrives.',
          style: TextStyle(color: c.textTertiary, fontSize: 11, height: 1.5),
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
                const SnackBar(
                    content: Text('Customer lookup cache cleared')),
              );
            },
            icon: Icon(Icons.delete_outline, color: c.textTertiary),
            label: Text('Clear Cache',
                style: TextStyle(color: c.textTertiary)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: c.border),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Lookup results are cached per number during the session. Clear the cache if you\'ve updated contact data in your CRM and want fresh results immediately.',
          style: TextStyle(color: c.textTertiary, fontSize: 11, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildPlaceholderRow(String placeholder, String description) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            placeholder,
            style: TextStyle(
              color: c.primary,
              fontSize: 11,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(description,
                style: TextStyle(color: c.textSecondary, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _buildScreenPopTab() {
    final c = context.colors;
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
          color: context.colors.accent,
          text: '',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Supported placeholders',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                      fontSize: 13)),
              const SizedBox(height: 6),
              Text(
                '%NUMBER%, %NAME%, %COMPANY%, %EXTID%, %DID%, %ID%, %ACCOUNT_ID%, %STATE%, %DIRECTION%, %CONTACT_LINK%',
                style: TextStyle(
                    color: c.textSecondary.withValues(alpha: 0.8),
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
          decoration: const InputDecoration(
            labelText: 'Trigger Event',
            contentPadding:
                EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          ),
          items: const [
            DropdownMenuItem(value: 'ring', child: Text('Incoming Call Ring')),
            DropdownMenuItem(value: 'answer', child: Text('Call Answered')),
            DropdownMenuItem(value: 'end', child: Text('Call Ended')),
          ],
          onChanged: (value) async {
            if (value != null) await _settings.setScreenPopEvent(value);
          },
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: Text('Open in Browser',
              style: TextStyle(color: c.textPrimary)),
          subtitle: Text('If off, send background HTTP request',
              style: TextStyle(color: c.textTertiary, fontSize: 12)),
          value: _settings.screenPopOpenBrowser,
          activeThumbColor: c.primary,
          contentPadding: EdgeInsets.zero,
          onChanged: (value) async {
            await _settings.setScreenPopOpenBrowser(value);
            setState(() {});
          },
        ),
        SwitchListTile(
          title: Text('Suppress Main Window',
              style: TextStyle(color: c.textPrimary)),
          subtitle: Text('Don\'t show PacketDial window on screen pop',
              style: TextStyle(color: c.textTertiary, fontSize: 12)),
          value: _settings.screenPopSuppressWindow,
          activeThumbColor: c.primary,
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
    final c = context.colors;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SectionTitle('Recording Upload'),
        const SizedBox(height: 8),
        const InfoBanner(
          icon: Icons.cloud_upload_outlined,
          text:
              'Automatically upload locally saved call recordings to your server via HTTP POST.',
        ),
        const SizedBox(height: 24),
        SwitchListTile(
          title: Text('Enable Recording Upload',
              style: TextStyle(color: c.textPrimary)),
          subtitle: Text('Upload recordings after calls end',
              style: TextStyle(color: c.textTertiary, fontSize: 12)),
          value: _settings.recordingUploadEnabled,
          activeThumbColor: c.primary,
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
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon, size: 18) : null,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      ),
    );
  }

  Widget _buildSaveButton(VoidCallback onPressed) {
    final c = context.colors;
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.save, size: 18),
        label: const Text('Save Settings'),
        style: FilledButton.styleFrom(
          backgroundColor: c.primary,
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
