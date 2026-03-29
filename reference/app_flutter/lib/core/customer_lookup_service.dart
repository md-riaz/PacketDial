import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/customer_data.dart';
import 'app_settings_service.dart';

/// Service for looking up customer data from CRM web services
class CustomerLookupService {
  CustomerLookupService._();
  static final CustomerLookupService instance = CustomerLookupService._();

  final _client = http.Client();

  /// Cache for customer data (phone number -> customer data)
  final Map<String, CustomerData> _cache = {};

  /// Look up customer data from the configured web service
  Future<CustomerData?> lookup(String phoneNumber, {String? extid}) async {
    final settings = AppSettingsService.instance;
    
    if (!settings.customerLookupEnabled || settings.customerLookupUrl.isEmpty) {
      return null;
    }

    // Build URL with placeholders — use the number as-is from the SIP URI
    final transformedNumber = phoneNumber.trim();
    String url = settings.customerLookupUrl;
    url = url.replaceAll('%NUMBER%', Uri.encodeComponent(transformedNumber));
    if (extid != null && extid.isNotEmpty) {
      url = url.replaceAll('%EXTID%', Uri.encodeComponent(extid));
    }
    
    // Check cache first
    final cacheKey = '$transformedNumber|$extid';
    if (_cache.containsKey(cacheKey)) {
      debugPrint('[CustomerLookup] Cache hit for $cacheKey');
      return _cache[cacheKey];
    }

    debugPrint('[CRM] Lookup → $url');

    try {
      final sw = Stopwatch()..start();
      final response = await _client.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
        },
      ).timeout(
        Duration(milliseconds: settings.customerLookupTimeoutMs),
      );
      sw.stop();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final customerData = CustomerData.fromJson(json);
        _cache[cacheKey] = customerData;
        debugPrint(
          '[CRM] OK ${response.statusCode} (${sw.elapsedMilliseconds}ms)'
          ' name="${customerData.contactName}"'
          ' company="${customerData.company}"',
        );
        return customerData;
      } else {
        debugPrint(
          '[CRM] FAIL ${response.statusCode} (${sw.elapsedMilliseconds}ms)',
        );
        return null;
      }
    } catch (e) {
      debugPrint('[CRM] ERROR $e');
      return null;
    }
  }

  /// Clear the customer data cache
  void clearCache() {
    _cache.clear();
    debugPrint('[CustomerLookup] Cache cleared');
  }

  /// Remove a specific entry from cache
  void removeFromCache(String phoneNumber) {
    final keysToRemove = _cache.keys.where((k) => k.startsWith(phoneNumber)).toList();
    for (final key in keysToRemove) {
      _cache.remove(key);
    }
  }

  /// Get cached customer data without making a new request
  CustomerData? getCached(String phoneNumber, {String? extid}) {
    final cacheKey = '$phoneNumber|$extid';
    return _cache[cacheKey];
  }

  /// Dispose of resources
  void dispose() {
    _client.close();
    _cache.clear();
  }
}
