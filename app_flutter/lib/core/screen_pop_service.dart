import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../models/call.dart';
import '../models/customer_data.dart';
import 'app_settings_service.dart';
import 'dialing_rules_service.dart';

/// Service for triggering screen pop on incoming calls
class ScreenPopService {
  ScreenPopService._();
  static final ScreenPopService instance = ScreenPopService._();

  final _client = http.Client();
  final _dialingRules = DialingRulesService.instance;

  /// Trigger screen pop based on settings
  Future<void> onIncomingCall(
    ActiveCall call, {
    CustomerData? customerData,
    String? extid,
    String? didNumber,
  }) async {
    final settings = AppSettingsService.instance;
    
    if (settings.screenPopUrl.isEmpty) {
      return;
    }

    // Check if we should trigger on this event
    final shouldTrigger = settings.screenPopEvent == 'ring';
    if (!shouldTrigger) {
      return;
    }

    await _triggerScreenPop(
      settings.screenPopUrl,
      call,
      customerData: customerData,
      extid: extid,
      didNumber: didNumber,
      openBrowser: settings.screenPopOpenBrowser,
    );
  }

  /// Trigger screen pop when call is answered
  Future<void> onCallAnswered(
    ActiveCall call, {
    CustomerData? customerData,
    String? extid,
    String? didNumber,
  }) async {
    final settings = AppSettingsService.instance;
    
    if (settings.screenPopUrl.isEmpty) {
      return;
    }

    // Check if we should trigger on this event
    final shouldTrigger = settings.screenPopEvent == 'answer';
    if (!shouldTrigger) {
      return;
    }

    await _triggerScreenPop(
      settings.screenPopUrl,
      call,
      customerData: customerData,
      extid: extid,
      didNumber: didNumber,
      openBrowser: settings.screenPopOpenBrowser,
    );
  }

  /// Internal method to trigger screen pop
  Future<void> _triggerScreenPop(
    String urlTemplate,
    ActiveCall call, {
    CustomerData? customerData,
    String? extid,
    String? didNumber,
    required bool openBrowser,
  }) async {
    // Build URL with placeholders
    String url = _replacePlaceholders(
      urlTemplate,
      call,
      customerData: customerData,
      extid: extid,
      didNumber: didNumber,
    );

    debugPrint('[ScreenPop] Triggering: $url (openBrowser: $openBrowser)');

    try {
      if (openBrowser) {
        // Open in default browser
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          debugPrint('[ScreenPop] Opened in browser');
        } else {
          debugPrint('[ScreenPop] Cannot launch URL');
        }
      } else {
        // Send background HTTP GET request
        final response = await _client.get(Uri.parse(url));
        debugPrint('[ScreenPop] HTTP response: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[ScreenPop] Error: $e');
    }
  }

  /// Replace placeholders in URL template
  String _replacePlaceholders(
    String template,
    ActiveCall call, {
    CustomerData? customerData,
    String? extid,
    String? didNumber,
  }) {
    var result = template;
    
    // Transform number using dialing rules
    final transformedNumber = _dialingRules.transform(call.uri);
    
    // Replace placeholders
    result = result.replaceAll('%NUMBER%', Uri.encodeComponent(transformedNumber));
    result = result.replaceAll('%NAME%', Uri.encodeComponent(customerData?.contactName ?? ''));
    result = result.replaceAll('%COMPANY%', Uri.encodeComponent(customerData?.company ?? ''));
    result = result.replaceAll('%EXTID%', Uri.encodeComponent(extid ?? ''));
    result = result.replaceAll('%DID%', Uri.encodeComponent(didNumber ?? ''));
    result = result.replaceAll('%ID%', call.callId.toString());
    result = result.replaceAll('%DIRECTION%', call.direction.name);
    result = result.replaceAll('%ACCOUNT_ID%', call.accountId);
    result = result.replaceAll('%STATE%', call.state.name);
    
    // Contact link from customer data
    if (customerData?.hasContactLink == true) {
      result = result.replaceAll('%CONTACT_LINK%', Uri.encodeComponent(customerData!.contactLink));
    }
    
    return result;
  }

  /// Dispose of resources
  void dispose() {
    _client.close();
  }
}
