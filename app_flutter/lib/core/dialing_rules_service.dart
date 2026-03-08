import 'app_settings_service.dart';

/// Service for transforming phone numbers before dialing
class DialingRulesService {
  DialingRulesService._();
  static final DialingRulesService instance = DialingRulesService._();

  /// Check if a string looks like a phone number
  bool isValidPhoneNumber(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    
    // Basic phone number pattern (international format)
    final phoneRegex = RegExp(r'^[\+]?[(]?[0-9]{1,4}[)]?[-\s\.]?[(]?[0-9]{1,4}[)]?[-\s\.]?[0-9]{1,9}$');
    if (!phoneRegex.hasMatch(trimmed)) return false;
    
    // Must have at least 7 digits
    final digits = trimmed.replaceAll(RegExp(r'[^\d]'), '');
    return digits.length >= 7;
  }

  /// Extract phone numbers from arbitrary text
  List<String> extractPhoneNumbers(String text) {
    final numbers = <String>[];
    
    // Pattern to match various phone number formats
    final patterns = [
      RegExp(r'\+?\d[\d\s\-\(\)]{7,}\d'),
      RegExp(r'\+?\d{1,4}\s?\d{1,4}\s?\d{1,9}'),
      RegExp(r'\+?\d{1,4}-\d{1,4}-\d{1,9}'),
      RegExp(r'\+?\d{1,4}\.\d{1,4}\.\d{1,9}'),
    ];
    
    for (final pattern in patterns) {
      final matches = pattern.allMatches(text);
      for (final match in matches) {
        final candidate = match.group(0)?.trim() ?? '';
        if (isValidPhoneNumber(candidate) && !numbers.contains(candidate)) {
          numbers.add(candidate);
        }
      }
    }
    
    return numbers;
  }

  /// Transform a phone number using all enabled dialing rules
  String transform(String number) {
    return AppSettingsService.instance.transformNumber(number);
  }

  /// Parse and transform a number, returning a clean dialable format
  String parseAndTransform(String input) {
    // First extract just the number part (remove any URI parameters)
    String number = input;
    final semicolonIndex = input.indexOf(';');
    if (semicolonIndex > 0) {
      number = input.substring(0, semicolonIndex);
    }
    
    // Remove common non-digit characters except +
    number = number.replaceAll(RegExp(r'[^\d+]'), '');
    
    // Apply dialing rules
    return transform(number);
  }

  /// Extract extid from URI with parameters
  String? extractExtId(String uri) {
    final extIdMatch = RegExp(r';extid=([^;]+)').firstMatch(uri);
    return extIdMatch?.group(1);
  }

  /// Extract sip_id from URI with parameters
  String? extractSipId(String uri) {
    final sipIdMatch = RegExp(r';sip_id=([^;]+)').firstMatch(uri);
    return sipIdMatch?.group(1);
  }

  /// Parse a tel:, callto:, or sip: URI and extract components
  Map<String, String?> parseUri(String uri) {
    // Remove scheme prefix
    String withoutScheme = uri;
    String scheme = '';
    
    if (uri.startsWith('tel:')) {
      scheme = 'tel';
      withoutScheme = uri.substring(4);
    } else if (uri.startsWith('callto:')) {
      scheme = 'callto';
      withoutScheme = uri.substring(7);
    } else if (uri.startsWith('sip:')) {
      scheme = 'sip';
      withoutScheme = uri.substring(4);
    }
    
    // Extract number and parameters
    final semicolonIndex = withoutScheme.indexOf(';');
    String number;
    String params;
    
    if (semicolonIndex > 0) {
      number = withoutScheme.substring(0, semicolonIndex);
      params = withoutScheme.substring(semicolonIndex + 1);
    } else {
      number = withoutScheme;
      params = '';
    }
    
    // Parse parameters
    final extId = extractExtId(uri);
    final sipId = extractSipId(uri);
    
    return {
      'scheme': scheme,
      'number': number,
      'extid': extId,
      'sip_id': sipId,
      'params': params,
    };
  }
}
