import 'package:phone_numbers_parser/phone_numbers_parser.dart';

/// Utilities for parsing SIP URIs into human-friendly display names.
class SipUriUtils {
  SipUriUtils._();

  /// Extracts a human-friendly name from a SIP URI.
  ///
  /// Examples:
  ///   "sip:1000@pbx.example.com"     → "1000"
  ///   "sips:john@sip.provider.com"    → "john"
  ///   "sip:+15551234567@gateway.com"  → "+1 555-123-4567"
  ///   "1000"                          → "1000"
  ///   "<sip:1000@host>;tag=abc"       → "1000"
  ///   '"Alice" <sip:alice@host>'      → "Alice"
  static String friendlyName(String? raw) {
    if (raw == null || raw.isEmpty) return 'Unknown';

    String input = raw.trim();

    // Check for display name in quotes: "Alice" <sip:...>
    final quotedMatch = RegExp(r'^"([^"]+)"').firstMatch(input);
    if (quotedMatch != null) {
      return quotedMatch.group(1)!.trim();
    }

    // Strip angle brackets: <sip:user@host> → sip:user@host
    final angleMatch = RegExp(r'<([^>]+)>').firstMatch(input);
    if (angleMatch != null) {
      input = angleMatch.group(1)!;
    }

    // Strip URI parameters (;tag=..., ;transport=...)
    final semiIdx = input.indexOf(';');
    if (semiIdx > 0) {
      input = input.substring(0, semiIdx);
    }

    // Strip sip: or sips: scheme
    if (input.toLowerCase().startsWith('sip:')) {
      input = input.substring(4);
    } else if (input.toLowerCase().startsWith('sips:')) {
      input = input.substring(5);
    }

    // Strip @domain
    final atIdx = input.indexOf('@');
    if (atIdx > 0) {
      input = input.substring(0, atIdx);
    }

    // Try to format as phone number using phone_numbers_parser
    final formatted = _tryFormatPhone(input);
    return formatted.isNotEmpty ? formatted : 'Unknown';
  }

  /// Extracts just the domain/server portion of a SIP URI.
  ///
  /// "sip:1000@pbx.example.com" → "pbx.example.com"
  static String? extractDomain(String? raw) {
    if (raw == null || raw.isEmpty) return null;

    String input = raw.trim();

    // Strip angle brackets
    final angleMatch = RegExp(r'<([^>]+)>').firstMatch(input);
    if (angleMatch != null) {
      input = angleMatch.group(1)!;
    }

    // Strip parameters
    final semiIdx = input.indexOf(';');
    if (semiIdx > 0) {
      input = input.substring(0, semiIdx);
    }

    // Strip scheme
    if (input.toLowerCase().startsWith('sip:')) {
      input = input.substring(4);
    } else if (input.toLowerCase().startsWith('sips:')) {
      input = input.substring(5);
    }

    // Get domain part
    final atIdx = input.indexOf('@');
    if (atIdx >= 0 && atIdx < input.length - 1) {
      return input.substring(atIdx + 1);
    }
    return null;
  }

  /// Attempts to format a string as a phone number using phone_numbers_parser.
  /// Falls back to the original string if it doesn't look like a phone number.
  static String _tryFormatPhone(String input) {
    if (input.isEmpty) return input;

    // Only attempt phone parsing if the input looks like a number
    // (starts with + or digit, and mostly contains digits)
    final digitsOnly = input.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.length < 3) return input; // Too short to be a phone number

    // If it doesn't start with + or a digit, it's a username, not a number
    if (!input.startsWith('+') && !RegExp(r'^\d').hasMatch(input)) {
      return input;
    }

    try {
      final phoneNumber = PhoneNumber.parse(input, callerCountry: IsoCode.BD);
      if (phoneNumber.isValid()) {
        return phoneNumber.formatNsn();
      }
    } catch (_) {
      // Not a valid phone number — return as-is
    }

    return input;
  }
}
