import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'app_settings_service.dart';
import 'customer_lookup_service.dart';
import 'screen_pop_service.dart';
import 'dialing_rules_service.dart';
import 'sip_uri_utils.dart';
import 'call_event_service.dart';
import '../models/call.dart';
import '../models/customer_data.dart';

class IntegrationService {
  IntegrationService._() {
    // Subscribe to call events from the event bus
    CallEventService.instance.eventStream.listen(_onCallEvent);
  }

  static final IntegrationService instance = IntegrationService._();

  final _client = http.Client();
  CustomerData? _lastCustomerData;
  String? _lastExtId;
  String? _lastDidNumber;

  // Track active calls to prevent duplicate event handling
  final Set<int> _ringingCalls = {};
  final Set<int> _answeredCalls = {};
  final Set<int> _endedCalls = {};

  /// Handle call events from the event stream.
  void _onCallEvent(CallEvent event) {
    // FlutterEventBus guarantees this is called on the platform thread,
    // so it's safe to call platform channels (HTTP, screen pop, etc.)
    final state = event.state.toLowerCase();
    final direction = event.direction.toLowerCase();

    if (direction == 'incoming' && state == 'callstate.ringing') {
      // Guard: Prevent duplicate ring events for same call
      if (_ringingCalls.contains(event.callId)) return;
      _ringingCalls.add(event.callId);

      // Create a minimal ActiveCall for integration
      final call = ActiveCall(
        callId: event.callId,
        accountId: event.accountId,
        uri: event.uri,
        direction: CallDirection.incoming,
        state: CallState.ringing,
        muted: false,
        onHold: false,
      );

      // Fire and forget - don't block the event stream
      onIncomingCall(
        call,
        extid: event.extid,
        didNumber: null,
      );
    } else if (state == 'callstate.incall') {
      // Guard: Prevent duplicate answer events for same call
      if (_answeredCalls.contains(event.callId)) return;
      _answeredCalls.add(event.callId);
      _ringingCalls.remove(event.callId);

      final call = ActiveCall(
        callId: event.callId,
        accountId: event.accountId,
        uri: event.uri,
        direction: direction == 'incoming' ? CallDirection.incoming : CallDirection.outgoing,
        state: CallState.inCall,
        muted: false,
        onHold: false,
      );

      onCallAnswered(call);
    } else if (state == 'callstate.ended') {
      // Guard: Prevent duplicate end events for same call
      if (_endedCalls.contains(event.callId)) return;
      _endedCalls.add(event.callId);
      _ringingCalls.remove(event.callId);
      _answeredCalls.remove(event.callId);

      final call = ActiveCall(
        callId: event.callId,
        accountId: event.accountId,
        uri: event.uri,
        direction: direction == 'incoming' ? CallDirection.incoming : CallDirection.outgoing,
        state: CallState.ended,
        muted: false,
        onHold: false,
      );

      onCallEnd(call, recordingPath: null);

      // Cleanup: Remove from tracking after a delay
      Future.delayed(const Duration(seconds: 5), () {
        _endedCalls.remove(event.callId);
      });
    }
  }

  /// Called when an incoming call starts ringing.
  Future<void> onIncomingCall(
    ActiveCall call, {
    String? extid,
    String? didNumber,
  }) async {
    _lastExtId = extid;
    _lastDidNumber = didNumber;

    // 1. Look up customer data from CRM
    final customerData = await CustomerLookupService.instance.lookup(
      call.uri,
      extid: extid,
    );
    _lastCustomerData = customerData;

    // 2. Trigger Ring Webhook
    final settings = AppSettingsService.instance;
    final urlTemplate = settings.ringWebhookUrl;
    if (settings.ringWebhookEnabled && urlTemplate.isNotEmpty) {
      final url = _replacePlaceholders(
        urlTemplate,
        call,
        customerData: customerData,
        extid: extid,
        didNumber: didNumber,
      );
      debugPrint('[IntegrationService] Triggering Ring Webhook: $url');
      try {
        await _client.get(Uri.parse(url));
      } catch (e) {
        debugPrint('[IntegrationService] Ring Webhook Error: $e');
      }
    }

    // 3. Trigger Screen Pop
    await ScreenPopService.instance.onIncomingCall(
      call,
      customerData: customerData,
      extid: extid,
      didNumber: didNumber,
    );
  }

  /// Called when a call is answered - trigger screen pop if configured for answer event
  Future<void> onCallAnswered(ActiveCall call) async {
    await ScreenPopService.instance.onCallAnswered(
      call,
      customerData: _lastCustomerData,
      extid: _lastExtId,
      didNumber: _lastDidNumber,
    );
  }

  /// Called when a call ends.
  Future<void> onCallEnd(ActiveCall call, {String? recordingPath}) async {
    final settings = AppSettingsService.instance;

    // 0. Trigger Screen Pop (if configured for call end event)
    await ScreenPopService.instance.onCallEnded(
      call,
      customerData: _lastCustomerData,
      extid: _lastExtId,
      didNumber: _lastDidNumber,
    );

    // 1. Trigger End Webhook
    if (settings.callEndWebhookEnabled && settings.endWebhookUrl.isNotEmpty) {
      final url = _replacePlaceholders(
        settings.endWebhookUrl,
        call,
        recordingPath: recordingPath,
      );
      debugPrint('[IntegrationService] Triggering End Webhook: $url');
      try {
        await _client.get(Uri.parse(url));
      } catch (e) {
        debugPrint('[IntegrationService] End Webhook Error: $e');
      }
    }

    // 2. Upload recording if configured
    if (recordingPath != null &&
        recordingPath.isNotEmpty &&
        settings.recordingUploadEnabled &&
        settings.recordingUploadUrl.isNotEmpty) {
      await _uploadRecording(settings.recordingUploadUrl, recordingPath, call);
    }
  }

  Future<void> _uploadRecording(
      String url, String path, ActiveCall call) async {
    final fieldName = AppSettingsService.instance.recordingFileFieldName;
    debugPrint('[IntegrationService] Uploading recording to $url');

    try {
      final request = http.MultipartRequest('POST', Uri.parse(url));
      request.files.add(await http.MultipartFile.fromPath(fieldName, path));

      // Add metadata fields
      final normalizedNumber = DialingRulesService.instance.transform(
        (SipUriUtils.extractNumber(call.uri) ?? call.uri).trim(),
      );
      request.fields['call_id'] = call.callId.toString();
      request.fields['number'] = normalizedNumber;
      request.fields['direction'] = call.direction.name;
      if (_lastCustomerData != null) {
        request.fields['contact_name'] = _lastCustomerData!.contactName;
        request.fields['company'] = _lastCustomerData!.company;
      }

      final response = await request.send();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('[IntegrationService] Recording upload successful');
      } else {
        debugPrint(
            '[IntegrationService] Recording upload failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[IntegrationService] Recording upload error: $e');
    }
  }

  String _replacePlaceholders(
    String template,
    ActiveCall call, {
    CustomerData? customerData,
    String? recordingPath,
    String? extid,
    String? didNumber,
  }) {
    var result = template;

    // Parse SIP URI first so placeholders never leak raw display-uri format.
    final extractedNumber = SipUriUtils.extractNumber(call.uri) ?? call.uri;
    final transformedNumber =
        DialingRulesService.instance.transform(extractedNumber.trim());
    final fallbackName = SipUriUtils.friendlyName(call.uri);
    final resolvedName = (customerData?.contactName.trim().isNotEmpty ?? false)
        ? customerData!.contactName.trim()
        : fallbackName;
    final resolvedCompany = customerData?.company.trim() ?? '';

    result =
        result.replaceAll('%NUMBER%', Uri.encodeComponent(transformedNumber));
    result = result.replaceAll('%NAME%', Uri.encodeComponent(resolvedName));
    result =
        result.replaceAll('%COMPANY%', Uri.encodeComponent(resolvedCompany));
    result = result.replaceAll('%EXTID%', Uri.encodeComponent(extid ?? ''));
    result = result.replaceAll('%DID%', Uri.encodeComponent(didNumber ?? ''));
    result = result.replaceAll('%ID%', call.callId.toString());
    result = result.replaceAll('%DIRECTION%', call.direction.name);
    result = result.replaceAll('%ACCOUNT_ID%', call.accountId);
    result = result.replaceAll('%STATE%', call.state.name);
    result = result.replaceAll(
      '%CONTACT_LINK%',
      Uri.encodeComponent(customerData?.contactLink ?? ''),
    );

    if (call.startedAt != null) {
      final duration = DateTime.now().difference(call.startedAt!).inSeconds;
      result = result.replaceAll('%DURATION%', duration.toString());
    } else {
      result = result.replaceAll('%DURATION%', '0');
    }

    if (recordingPath != null && recordingPath.isNotEmpty) {
      result =
          result.replaceAll('%RECORD%', Uri.encodeComponent(recordingPath));
      result = result.replaceAll(
        '%RECORDFILENAME%',
        Uri.encodeComponent(Uri.parse(recordingPath).pathSegments.last),
      );
    }

    return result;
  }

  /// Get the last looked up customer data
  CustomerData? get lastCustomerData => _lastCustomerData;

  /// Get the last extid
  String? get lastExtId => _lastExtId;

  /// Get the last DID number
  String? get lastDidNumber => _lastDidNumber;

  /// Clear cached customer data
  void clearCustomerData() {
    _lastCustomerData = null;
    _lastExtId = null;
    _lastDidNumber = null;
  }

  /// Dispose of resources
  void dispose() {
    _client.close();
  }
}
