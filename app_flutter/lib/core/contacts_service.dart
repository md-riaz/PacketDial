import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'path_provider_service.dart';

/// Contact entry for BLF/Presence monitoring.
class BlfContact {
  final String id;
  final String name;
  final String sipUri;
  final String? extension;
  String presenceState; // 'Unknown', 'Available', 'Busy', 'Ringing'
  String? activity;

  BlfContact({
    required this.id,
    required this.name,
    required this.sipUri,
    this.extension,
    this.presenceState = 'Unknown',
    this.activity,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'sip_uri': sipUri,
        'extension': extension,
        'presence_state': presenceState,
        'activity': activity,
      };

  factory BlfContact.fromJson(Map<String, dynamic> json) => BlfContact(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        sipUri: json['sip_uri'] ?? '',
        extension: json['extension'],
        presenceState: json['presence_state'] ?? 'Unknown',
        activity: json['activity'],
      );
}

/// Manages BLF contact list with file-based persistence.
/// Contacts are loaded on app startup and persisted automatically.
class ContactsService {
  ContactsService._();
  static final ContactsService instance = ContactsService._();

  final List<BlfContact> _contacts = [];
  bool _isLoaded = false;
  String? _accountId;

  /// Get all contacts.
  List<BlfContact> get contacts => List.unmodifiable(_contacts);

  /// Check if contacts are loaded.
  bool get isLoaded => _isLoaded;

  /// Get account ID for BLF subscription.
  String? get accountId => _accountId;

  /// Load contacts from file.
  /// Call this during app initialization.
  Future<void> loadContacts() async {
    if (_isLoaded) return;

    try {
      final file = await _getContactsFile();
      if (await file.exists()) {
        final jsonStr = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(jsonStr);
        _contacts.clear();
        _contacts.addAll(
          jsonList.map((j) => BlfContact.fromJson(j)).toList(),
        );
        debugPrint('[ContactsService] Loaded ${_contacts.length} contacts');
      } else {
        // Save empty list to create the file
        await saveContacts();
        debugPrint('[ContactsService] Created initial contacts file');
      }
    } catch (e) {
      debugPrint('[ContactsService] Error loading contacts: $e');
      // Start with empty list on error
      _contacts.clear();
    }

    _isLoaded = true;
  }

  /// Save contacts to file.
  Future<void> saveContacts() async {
    try {
      final file = await _getContactsFile();
      final jsonList = _contacts.map((c) => c.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList), flush: true);
      debugPrint('[ContactsService] Saved ${_contacts.length} contacts');
    } catch (e) {
      debugPrint('[ContactsService] Error saving contacts: $e');
    }
  }

  /// Set account ID for BLF subscription.
  void setAccountId(String accountId) {
    _accountId = accountId;
  }

  /// Add a new contact.
  Future<void> addContact(BlfContact contact) async {
    _contacts.add(contact);
    await saveContacts();
  }

  /// Update existing contact.
  Future<void> updateContact(BlfContact contact) async {
    final index = _contacts.indexWhere((c) => c.id == contact.id);
    if (index >= 0) {
      _contacts[index] = contact;
      await saveContacts();
    }
  }

  /// Delete contact by ID.
  Future<void> deleteContact(String id) async {
    _contacts.removeWhere((c) => c.id == id);
    await saveContacts();
  }

  /// Update presence state for a SIP URI.
  void updatePresence(String sipUri, String state, String? activity) {
    debugPrint(
      '[ContactsService] updatePresence target="$sipUri" state="$state" activity="${activity ?? ""}"',
    );
    final contact = _contacts.firstWhere(
      (c) => _matchesPresenceTarget(c, sipUri),
      orElse: () => BlfContact(id: '', name: sipUri, sipUri: sipUri),
    );
    if (contact.id.isNotEmpty) {
      debugPrint(
        '[ContactsService] matched contact id=${contact.id} name="${contact.name}" sipUri="${contact.sipUri}" ext="${contact.extension ?? ""}"',
      );
      contact.presenceState = state;
      contact.activity = activity;
      // Don't save presence to file - it's runtime state only
    } else {
      debugPrint(
        '[ContactsService] no contact matched target="$sipUri"; known contacts=${_contacts.length}',
      );
    }
  }

  /// Get contact by SIP URI.
  BlfContact? getByUri(String sipUri) {
    try {
      return _contacts.firstWhere((c) => _matchesPresenceTarget(c, sipUri));
    } catch (_) {
      return null;
    }
  }

  /// Get contacts by presence state.
  List<BlfContact> getByPresence(String state) {
    return _contacts.where((c) => c.presenceState == state).toList();
  }

  /// Import contacts from JSON file.
  Future<bool> importContacts(File file) async {
    try {
      final jsonStr = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(jsonStr);
      final imported = jsonList.map((j) => BlfContact.fromJson(j)).toList();
      _contacts.addAll(imported);
      await saveContacts();
      debugPrint('[ContactsService] Imported ${imported.length} contacts');
      return true;
    } catch (e) {
      debugPrint('[ContactsService] Import error: $e');
      return false;
    }
  }

  /// Export contacts to JSON file.
  Future<bool> exportContacts(File file) async {
    try {
      final jsonList = _contacts.map((c) => c.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
      debugPrint('[ContactsService] Exported ${_contacts.length} contacts');
      return true;
    } catch (e) {
      debugPrint('[ContactsService] Export error: $e');
      return false;
    }
  }

  /// Clear all contacts.
  Future<void> clearAll() async {
    _contacts.clear();
    await saveContacts();
  }

  /// Get contacts file path.
  Future<File> _getContactsFile() async {
    final dir = await PathProviderService.instance.getDataDirectory();
    return File('${dir.path}/blf_contacts.json');
  }

  /// Get default contacts file for import/export.
  Future<File> getDefaultExportFile() async {
    final dir = await PathProviderService.instance.getDataDirectory();
    return File('${dir.path}/packetdial_contacts.json');
  }

  bool _matchesPresenceTarget(BlfContact contact, String target) {
    final normalizedTarget = _normalizePresenceKey(target);
    if (normalizedTarget.isEmpty) return false;

    final candidates = <String>[
      contact.sipUri,
      if (contact.extension != null) contact.extension!,
    ];

    for (final candidate in candidates) {
      final normalizedCandidate = _normalizePresenceKey(candidate);
      debugPrint(
        '[ContactsService] compare target="$normalizedTarget" candidate="$normalizedCandidate" raw="$candidate"',
      );
      if (normalizedCandidate == normalizedTarget) {
        return true;
      }
    }

    return false;
  }

  String _normalizePresenceKey(String value) {
    final trimmed = value.trim().toLowerCase();
    if (trimmed.isEmpty) return '';

    var normalized = trimmed;
    if (normalized.startsWith('sip:')) {
      normalized = normalized.substring(4);
    }
    final atIndex = normalized.indexOf('@');
    if (atIndex >= 0) {
      normalized = normalized.substring(0, atIndex);
    }
    if (normalized.startsWith('<') && normalized.endsWith('>')) {
      normalized = normalized.substring(1, normalized.length - 1);
    }
    return normalized.trim();
  }
}
