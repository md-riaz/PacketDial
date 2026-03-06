# Softphone.pro Feature Analysis & Implementation Plan for PacketDial

## Executive Summary

This document analyzes the integration features from Softphone.pro and provides a comprehensive implementation plan for integrating these capabilities into PacketDial. The analysis covers **8 core integration features** with detailed technical specifications and a phased implementation roadmap.

---

## Table of Contents

1. [Feature Analysis](#1-feature-analysis)
   - 1.1 Command-Line Parameters
   - 1.2 Click-to-Call (URI Schemes)
   - 1.3 Customer Data from 3rd-Party Systems
   - 1.4 Screen Pop on Incoming Calls
   - 1.5 Call from Clipboard
   - 1.6 Call Logging in Web Applications
   - 1.7 Call Recording Upload (HTTP)
   - 1.8 Click-to-Call in Windows Applications
2. [Current PacketDial State](#2-current-packetdial-state)
3. [Implementation Plan](#3-implementation-plan)
4. [Architecture Recommendations](#4-architecture-recommendations)
5. [Security Considerations](#5-security-considerations)
6. [Testing Strategy](#6-testing-strategy)
7. [Documentation Requirements](#7-documentation-requirements)

---

## 1. Feature Analysis

### 1.1 Command-Line Parameters

**Softphone.pro Implementation:**

| Parameter | Syntax | Description |
|-----------|--------|-------------|
| `-call` | `-call <number>[;extid=<id>][;sip_id=<id>][;did_id=<id>]` | Place outgoing call with optional tracking |
| `-transfer` | `-transfer <extension_or_number>` | Transfer active call |
| `-answer` | `-answer` | Answer incoming call |
| `-hangup` | `-hangup` | End active call |
| `-playprerecordedaudio` | `-playprerecordedaudio <ordinal>` | Play pre-recorded message |
| `-setstatus` | `-status <status>` | Set status (Online/Away/NA/Offline) |
| `-close` | `-close` | Close application |
| `-dtmf` | `-dtmf <tone_sequence>` | Send DTMF tones (v5.7+) |

**Key Design Decisions:**
- Single-instance architecture (parameters passed to running instance)
- Auto-start behavior when parameters detected
- Semicolon-delimited optional parameters for `-call`
- Status values limited to predefined set

**PacketDial Current State:**
- ✅ Has `pd.exe` CLI controller with Named Pipe communication
- ✅ Supports: `dial`, `answer`, `hangup`, `mute`, `events`
- ✅ Smart account selection (auto-picks registered account)
- ✅ Named Pipe API for bidirectional communication
- ❌ Missing: `-transfer`, `-dtmf`, `-setstatus`, `-close` commands
- ❌ No support for `extid`, `sip_id`, `did_id` parameters

---

### 1.2 Click-to-Call (URI Schemes)

**Softphone.pro Implementation:**

**Supported URI Schemes:**
```html
<a href="tel:+18004633339">+1 800 463 3339</a>
<a href="callto:+18004633339">+1 800 463 3339</a>
<a href="sip:+18004633339">+1 800 463 3339</a>
```

**Extended Parameters:**
```html
<!-- extid for CRM tracking -->
<a href="tel:+19001234567;extid=123456">+1 (900) 123-45-67</a>

<!-- sip_id for specific account -->
<a href="callto:+79001234567;sip_id=001">+7 (900) 123-45-67</a>
```

**Configuration:**
- Protocol handlers enabled in **Integration → Protocol Handlers**
- Windows registry registration for `tel:`, `callto:`, `sip:` schemes
- Optional: Prevent main window popup on outgoing calls

**PacketDial Current State:**
- ✅ Has `register_protocols.ps1` script for Windows protocol registration
- ✅ Supports `tel:` and `sip:` URI schemes
- ✅ Protocol handlers route to CLI bridge (`pd.exe`)
- ❌ No support for `extid` parameter in URI parsing
- ❌ No support for `sip_id` parameter for account selection
- ❌ No configuration to prevent window popup

---

### 1.3 Customer Data from 3rd-Party Systems

**Softphone.pro Implementation:**

**Architecture:**
```
Incoming Call → Softphone.Pro → HTTP GET → Web Service → JSON Response → Display in Notification
```

**Web Service Request:**
```
GET http://example.com/getcrminfo/getinfo.php?number=%NUMBER%
```

**JSON Response Format:**
```json
{
    "crm_info": {
        "number": "NUMBER",
        "contact_name": "NAME",
        "company": "COMPANY",
        "contact_link": "LINK"
    }
}
```

**Configuration:**
- **Settings → Integration → Third-party Systems → Add Handler**
- Event: "Incoming call ring"
- SIP Account: Specific or "All"
- Action: "Call a web service"
- URL: `http://example.com/getcrminfo/getinfo.php?number=%NUMBER%`

**PacketDial Current State:**
- ✅ Has `IntegrationService` with webhook support
- ✅ Has `onIncomingCall()` method that triggers ring webhook
- ✅ Supports URL placeholders (`%NUMBER%`, `%ID%`, `%DIRECTION%`, `%DURATION%`)
- ❌ No JSON response parsing for caller lookup
- ❌ No display of customer data in incoming call popup
- ❌ No configurable "contact link" for opening CRM records
- ❌ No support for `extid` parameter passthrough

---

### 1.4 Screen Pop on Incoming Calls

**Softphone.pro Implementation:**

**Two Screen Pop Methods:**

| Method | Behavior | Use Case |
|--------|----------|----------|
| **Open link in browser** | Opens URL in default browser | Display CRM records |
| **HTTP GET (background)** | Silent API call, no browser | Webhook triggers |

**Configuration:**
- **Settings → Integration → Third-party Systems → Add Handler**
- Event: "Incoming call ring" or "Incoming call answer"
- SIP Account: Specific or "All"
- Action: "Open link in web browser" or "HTTP GET request"
- URL: `https://your-crm.com/customer?phone={caller_id}`

**Advanced Features:**
- Regular expression support for Caller ID modification
- DID number can be sent to 3rd party systems
- Option to prevent main window popup

**PacketDial Current State:**
- ✅ Has webhook integration in `IntegrationService`
- ✅ Supports multiple event types (ring, end)
- ✅ URL placeholder replacement system
- ❌ No "open in browser" functionality
- ❌ No regex support for number transformation
- ❌ No DID number parameter support
- ❌ No configuration to suppress window popup

---

### 1.5 Call from Clipboard

**Softphone.pro Implementation:**

**How It Works:**
1. Clipboard monitoring enabled in settings
2. Phone number detected in clipboard
3. Bottom-right popup notification appears
4. User can modify number and click "Dial"
5. Uses currently selected SIP account

**Configuration:**
- **Settings → Clipboard → Monitor clipboard**
- Dialing rules can transform numbers before dialing

**PacketDial Current State:**
- ✅ Has global hotkey (Alt+D) to dial from clipboard
- ✅ Clipboard access implemented in `main.dart`
- ❌ No automatic clipboard monitoring (manual hotkey only)
- ❌ No bottom-right popup notification
- ❌ No dialing rules/number transformation system
- ❌ No number modification UI before dialing

---

### 1.6 Call Logging in Web Applications

**Softphone.pro Implementation:**

**Two Logging Methods:**

| Method | Behavior |
|--------|----------|
| **Open link in browser** | Opens URL in default browser |
| **HTTP GET (background)** | Silent API call |

**Available Parameters:**
- Caller ID (with regex modification support)
- DID Number
- `%RECORD%` - Full path to recording file

**Configuration:**
- **Settings → Integration → Third-party Systems → Add Handler**
- Event: "Call end"
- SIP Account: Specific or "All"
- URL: `[web-service]?param1=value1&param2=value2`

**Use Cases:**
- CRM integration for outbound call recognition
- Centralized call log storage
- Call recording archival

**PacketDial Current State:**
- ✅ Has `onCallEnd()` method in `IntegrationService`
- ✅ Supports webhook URL configuration
- ✅ URL placeholder replacement (`%NUMBER%`, `%ID%`, etc.)
- ✅ Recording path available in callback
- ❌ No "open in browser" option (only background HTTP)
- ❌ No regex support for Caller ID
- ❌ No DID number parameter
- ❌ No `%RECORD%` placeholder (recording path not in URL template)

---

### 1.7 Call Recording Upload (HTTP)

**Softphone.pro Implementation:**

**Upload Architecture:**
```
Call Ends → Event Handler → HTTP POST (multipart/form-data) → PHP Script → ./records/ folder
```

**Server-Side Requirements:**
- PHP script (`recording_upload.php`) in web server public folder
- Write permissions for web server process
- Default storage: `./records/` subfolder

**Configuration:**
- **Settings → Integration → Third-party Systems → Add Handler**
- Event: "Call end"
- Action: "Upload a call recording"
- URL: Full path to `recording_upload.php`
- Input field name: HTML `<input>` element name attribute

**API Structure:**
```
POST /recording_upload.php
Content-Type: multipart/form-data

File: <binary recording data>
Fields: call_id, number, direction (optional metadata)
```

**PacketDial Current State:**
- ✅ Has `_uploadRecording()` method in `IntegrationService`
- ✅ HTTP POST multipart upload implemented
- ✅ Metadata fields included (call_id, number, direction)
- ✅ Recording path passed from `CallStateChanged` event
- ❌ No configurable input field name (hardcoded)
- ❌ No `%RECORDFILENAME%` placeholder support
- ❌ No call recording feature implemented yet (TODO in README)

---

### 1.8 Click-to-Call in Windows Applications

**Softphone.pro Implementation:**

**Integration Method:**
```
Windows App → ShellExecute("SoftphonePro.exe -call <number>") → Call Initiated
```

**Related Configuration:**
- Dialing rules for number transformation
- Prevent main window popup option

**PacketDial Current State:**
- ✅ Has `pd.exe dial <number>` CLI command
- ✅ Named Pipe API for direct integration
- ✅ Documentation includes C# and Python examples
- ✅ Smart account selection for multi-account setups
- ❌ No dialing rules for number transformation
- ❌ No window popup suppression option

---

## 2. Current PacketDial State

### 2.1 Architecture Overview

```
Flutter Desktop UI
    ↕ Direct C ABI (FFI)
voip_core.dll (Rust)
    ↕ C shim FFI
PJSIP (C)
```

### 2.2 Existing Integration Infrastructure

**CLI Controller (`pd.exe`):**
- Commands: `dial`, `answer`, `hangup`, `mute`, `events`
- Named Pipe: `\\.\pipe\PacketDial.API`
- Bidirectional JSON communication
- Smart account selection

**Integration Service:**
```dart
class IntegrationService {
  Future<void> onIncomingCall(ActiveCall call);
  Future<void> onCallEnd(ActiveCall call, {String? recordingPath});
}
```

**Protocol Handlers:**
- Windows registry registration script
- `tel:` and `sip:` URI support
- Routes to CLI bridge

**Webhook System:**
- Ring webhook URL
- End webhook URL
- Recording upload URL
- Placeholder replacement (`%NUMBER%`, `%ID%`, etc.)

### 2.3 Gaps Identified

| Feature | Status | Priority |
|---------|--------|----------|
| CLI: `-transfer`, `-dtmf`, `-setstatus`, `-close` | ❌ Missing | High |
| URI: `extid`, `sip_id` parameters | ❌ Missing | High |
| Customer lookup (JSON response) | ❌ Missing | High |
| Screen pop (open in browser) | ❌ Missing | High |
| Clipboard auto-monitoring | ❌ Missing | Medium |
| Dialing rules/number transformation | ❌ Missing | High |
| Call recording | ❌ Missing | High |
| Regex for Caller ID | ❌ Missing | Medium |
| DID number parameter | ❌ Missing | Medium |
| Window popup suppression | ❌ Missing | Low |

---

## 3. Implementation Plan

### Phase 1: Foundation (Weeks 1-2)

#### 3.1.1 Enhanced CLI Controller

**Goal:** Extend `pd.exe` with missing commands

**Tasks:**
1. **Add `-transfer` command**
   ```powershell
   pd transfer <extension_or_number>
   ```
   - Validate active call exists
   - Send transfer command via Named Pipe
   - Return success/failure status

2. **Add `-dtmf` command**
   ```powershell
   pd dtmf <tone_sequence>
   ```
   - Validate active call exists
   - Send DTMF via Named Pipe (`CallDtmf` command)
   - Support: `0-9`, `*`, `#`, `A-D`

3. **Add `-setstatus` command**
   ```powershell
   pd status <Online|Away|NA|Offline>
   ```
   - Update presence status in engine
   - Broadcast status change event

4. **Add `-close` command**
   ```powershell
   pd close
   ```
   - Graceful shutdown with active call check
   - Save state before exit

5. **Extend `-dial` with parameters**
   ```powershell
   pd dial <number>[;extid=<id>][;sip_id=<uuid>]
   ```
   - Parse semicolon-delimited parameters
   - Pass `extid` to integration service
   - Use `sip_id` for account selection

**Files to Modify:**
- `core_rust/src/lib.rs` - Add CLI command handling
- New: `cli/pd_cli.rs` - Dedicated CLI module
- `app_flutter/lib/core/engine_channel.dart` - Add command support

---

#### 3.1.2 URI Parameter Parsing

**Goal:** Support `extid` and `sip_id` in URI schemes

**Tasks:**
1. **Extend URI parsing utility**
   ```dart
   class SipUriUtils {
     static ParsedUri parse(String uri) {
       // tel:+1234567890;extid=123456;sip_id=uuid
       // Returns: { number, extid, sip_id }
     }
   }
   ```

2. **Update protocol handler registration**
   - Modify registry entries to pass full URI with parameters
   - Ensure parameter preservation through shell execution

3. **Update dialer screen**
   - Accept parsed URI parameters
   - Use `sip_id` for account selection
   - Pass `extid` to integration service

**Files to Modify:**
- `app_flutter/lib/core/sip_uri_utils.dart` - Add parameter parsing
- `scripts/register_protocols.ps1` - Update registry
- `app_flutter/lib/screens/dialer_screen.dart` - Handle parameters

---

#### 3.1.3 Dialing Rules System

**Goal:** Transform phone numbers before dialing

**Tasks:**
1. **Define dialing rules model**
   ```dart
   class DialingRule {
     String id;
     String pattern;        // Regex pattern
     String replacement;    // Replacement string
     bool enabled;
     int priority;          // Order of application
   }
   ```

2. **Create dialing rules service**
   ```dart
   class DialingRulesService {
     String transform(String number);
     Future<void> addRule(DialingRule rule);
     Future<void> removeRule(String id);
   }
   ```

3. **Add settings UI**
   - Rules list with enable/disable toggle
   - Add/edit/delete rule dialogs
   - Test transformation preview

4. **Integrate with dialer**
   - Apply rules before placing calls
   - Apply rules to CLI commands
   - Apply rules to URI scheme calls

**Files to Create:**
- `app_flutter/lib/models/dialing_rule.dart`
- `app_flutter/lib/core/dialing_rules_service.dart`
- `app_flutter/lib/screens/dialing_rules_page.dart`

**Files to Modify:**
- `app_flutter/lib/screens/dialer_screen.dart`
- `app_flutter/lib/core/engine_channel.dart`

---

### Phase 2: CRM Integration (Weeks 3-4)

#### 3.2.1 Customer Lookup Service

**Goal:** Fetch customer data from web service on incoming calls

**Tasks:**
1. **Extend integration service**
   ```dart
   class IntegrationService {
     Future<CustomerData?> lookupCustomer(String number);
     Future<void> onIncomingCall(ActiveCall call, {String? extid});
   }
   ```

2. **Define customer data model**
   ```dart
   class CustomerData {
     String number;
     String contactName;
     String company;
     String contactLink;
     Map<String, dynamic> customFields;
   }
   ```

3. **Add settings configuration**
   - Customer lookup URL template
   - Timeout configuration
   - Enable/disable toggle
   - Test connection button

4. **Update incoming call popup**
   - Display customer name and company
   - Show "Open CRM" button if link available
   - Handle loading state

**Files to Create:**
- `app_flutter/lib/models/customer_data.dart`
- `app_flutter/lib/core/customer_lookup_service.dart`

**Files to Modify:**
- `app_flutter/lib/core/integration_service.dart`
- `app_flutter/lib/core/app_settings_service.dart`
- `app_flutter/lib/screens/incoming_call_popup.dart`

---

#### 3.2.2 Screen Pop Functionality

**Goal:** Open CRM URLs on incoming calls

**Tasks:**
1. **Add screen pop service**
   ```dart
   class ScreenPopService {
     Future<void> onIncomingCall(ActiveCall call);
     Future<void> openUrl(String urlTemplate, ActiveCall call);
   }
   ```

2. **Extend URL placeholder system**
   ```dart
   Map<String, String> placeholders = {
     '%NUMBER%': call.uri,
     '%NAME%': customerData?.contactName ?? '',
     '%COMPANY%': customerData?.company ?? '',
     '%EXTID%': extid ?? '',
     '%DID%': didNumber ?? '',
     '%ACCOUNT_ID%': call.accountId,
   };
   ```

3. **Add settings configuration**
   - Screen pop URL template
   - Event trigger (ring vs answer)
   - Open in browser vs background HTTP
   - Suppress main window popup option

4. **Implement browser launch**
   ```dart
   import 'package:url_launcher/url_launcher.dart';
   await launchUrl(Uri.parse(url));
   ```

**Files to Create:**
- `app_flutter/lib/core/screen_pop_service.dart`

**Files to Modify:**
- `app_flutter/lib/core/integration_service.dart`
- `app_flutter/lib/core/app_settings_service.dart`
- `app_flutter/lib/core/engine_channel.dart`

**Dependencies to Add:**
- `url_launcher: ^9.0.0` (pubspec.yaml)

---

#### 3.2.3 Extended Placeholder System

**Goal:** Support all Softphone.pro placeholders

**Tasks:**
1. **Extend placeholder replacement**
   ```dart
   String replacePlaceholders(String template, ActiveCall call, {
     CustomerData? customer,
     String? extid,
     String? didNumber,
     String? recordingPath,
   }) {
     var result = template;
     result = result.replaceAll('%NUMBER%', call.uri);
     result = result.replaceAll('%NAME%', customer?.contactName ?? '');
     result = result.replaceAll('%COMPANY%', customer?.company ?? '');
     result = result.replaceAll('%EXTID%', extid ?? '');
     result = result.replaceAll('%DID%', didNumber ?? '');
     result = result.replaceAll('%ID%', call.callId.toString());
     result = result.replaceAll('%DIRECTION%', call.direction.name);
     result = result.replaceAll('%ACCOUNT_ID%', call.accountId);
     result = result.replaceAll('%RECORD%', recordingPath ?? '');
     result = result.replaceAll('%RECORDFILENAME%', 
         recordingPath != null ? p.basename(recordingPath) : '');
     // ... duration, timestamp, etc.
     return result;
   }
   ```

2. **Add DID number support**
   - Extract from SIP headers (P-Asserted-Identity)
   - Store in ActiveCall model
   - Include in event callbacks

3. **Add regex transformation**
   ```dart
   class RegexTransformation {
     String pattern;
     String replacement;
     String apply(String input);
   }
   ```

**Files to Modify:**
- `app_flutter/lib/core/integration_service.dart`
- `app_flutter/lib/models/call.dart` - Add DID field

---

### Phase 3: Clipboard & Recording (Weeks 5-6)

#### 3.3.1 Clipboard Monitoring

**Goal:** Auto-detect phone numbers in clipboard

**Tasks:**
1. **Create clipboard monitoring service**
   ```dart
   class ClipboardMonitor {
     void startMonitoring();
     void stopMonitoring();
     bool get isMonitoring;
     final StreamController<String> onPhoneDetected = StreamController();
   }
   ```

2. **Implement phone number detection**
   ```dart
   bool isValidPhoneNumber(String text) {
     // Regex for international phone numbers
     final pattern = RegExp(r'^[\+]?[(]?[0-9]{1,4}[)]?[-\s\.]?[(]?[0-9]{1,4}[)]?[-\s\.]?[0-9]{1,9}$');
     return pattern.hasMatch(text.trim());
   }
   ```

3. **Create clipboard popup UI**
   - Bottom-right corner notification
   - Display detected number
   - Edit field for modification
   - Dial button

4. **Add settings configuration**
   - Enable/disable monitoring
   - Polling interval (default: 500ms)
   - Ignore duplicates option

**Files to Create:**
- `app_flutter/lib/core/clipboard_service.dart`
- `app_flutter/lib/widgets/clipboard_popup.dart`

**Files to Modify:**
- `app_flutter/lib/main.dart` - Initialize monitor
- `app_flutter/lib/core/app_settings_service.dart`

---

#### 3.3.2 Call Recording Infrastructure

**Goal:** Implement call recording with upload

**Tasks:**
1. **Add recording support to Rust core**
   ```rust
   // lib.rs
   pub fn start_call_recording(call_id: u32, path: &str) -> EngineErrorCode;
   pub fn stop_call_recording(call_id: u32) -> EngineErrorCode;
   pub fn get_recording_path(call_id: u32) -> Option<String>;
   ```

2. **Configure PJSIP recording**
   - Enable PJSIP call recording in shim
   - Set recording format (WAV/MP3)
   - Configure storage location

3. **Add recording service**
   ```dart
   class RecordingService {
     Future<void> startRecording(ActiveCall call);
     Future<void> stopRecording(ActiveCall call);
     String? getRecordingPath(ActiveCall call);
   }
   ```

4. **Update call history**
   - Store recording path in history entry
   - Add playback button in history screen
   - Add file browser for recordings

**Files to Create:**
- `app_flutter/lib/core/recording_service.dart`
- `app_flutter/lib/models/recording.dart`

**Files to Modify:**
- `core_rust/src/lib.rs` - Add recording FFI
- `app_flutter/lib/core/engine_channel.dart` - Handle recording events
- `app_flutter/lib/models/call_history_schema.dart` - Add recording path

**Dependencies to Add:**
- PJSIP recording libraries (vcpkg)

---

#### 3.3.3 Enhanced Recording Upload

**Goal:** Full-featured recording upload

**Tasks:**
1. **Extend upload configuration**
   - Upload URL template
   - Input field name configuration
   - Additional metadata fields

2. **Add upload status tracking**
   - Upload progress indicator
   - Retry on failure
   - Upload history log

3. **Support multiple upload destinations**
   - Primary server
   - Backup server
   - Local archive

**Files to Modify:**
- `app_flutter/lib/core/integration_service.dart`
- `app_flutter/lib/core/app_settings_service.dart`

---

### Phase 4: Advanced Features (Weeks 7-8)

#### 3.4.1 Regex Number Transformation

**Goal:** Support regex for Caller ID modification

**Tasks:**
1. **Add regex transformation model**
   ```dart
   class CallerIdTransformation {
     String id;
     String pattern;        // Regex pattern
     String replacement;    // Replacement with backreferences
     bool enabled;
   }
   ```

2. **Create transformation service**
   ```dart
   class CallerIdTransformationService {
     String transform(String callerId, List<CallerIdTransformation> rules);
   }
   ```

3. **Add settings UI**
   - Rules management (add/edit/delete)
   - Test transformation tool
   - Enable/disable toggle

4. **Integrate with integration service**
   - Apply transformation before webhook calls
   - Apply transformation before screen pop

**Files to Create:**
- `app_flutter/lib/models/caller_id_transformation.dart`
- `app_flutter/lib/core/caller_id_transformation_service.dart`

---

#### 3.4.2 DID Number Support

**Goal:** Extract and use DID number

**Tasks:**
1. **Extract DID from SIP headers**
   - Parse P-Asserted-Identity header
   - Parse Request-URI for called number
   - Store in ActiveCall model

2. **Add DID to event callbacks**
   - Include in webhook URLs
   - Include in screen pop URLs
   - Include in customer lookup

3. **Display DID in UI**
   - Incoming call popup
   - Call history
   - Active call screen

**Files to Modify:**
- `core_rust/src/lib.rs` - Extract DID from PJSIP
- `app_flutter/lib/models/call.dart` - Add DID field
- `app_flutter/lib/core/engine_channel.dart` - Parse DID from events

---

#### 3.4.3 Window Popup Suppression

**Goal:** Option to suppress main window on events

**Tasks:**
1. **Add suppression setting**
   - Suppress on outgoing calls
   - Suppress on incoming calls
   - Always show notification anyway

2. **Update window management**
   - Check setting before showing window
   - Still show tray notification
   - Still show incoming call popup

3. **Update CLI and URI handlers**
   - Respect suppression setting
   - Optional override parameter

**Files to Modify:**
- `app_flutter/lib/core/app_settings_service.dart`
- `app_flutter/lib/main.dart`
- `app_flutter/lib/core/multi_window/window_router.dart`

---

## 4. Architecture Recommendations

### 4.1 Service Layer Organization

```
app_flutter/lib/core/
├── integration_service.dart          # Webhook & upload orchestration
├── customer_lookup_service.dart      # CRM data fetching
├── screen_pop_service.dart           # Browser launch & HTTP triggers
├── clipboard_service.dart            # Clipboard monitoring
├── recording_service.dart            # Call recording control
├── dialing_rules_service.dart        # Number transformation
├── caller_id_transformation_service.dart  # Regex transformations
└── app_settings_service.dart         # Settings persistence
```

### 4.2 Event Flow Architecture

```
Incoming Call Event
    ↓
EngineChannel._handleEvent()
    ↓
IntegrationService.onIncomingCall()
    ├─→ CustomerLookupService.lookup()
    │       ↓
    │   HTTP GET → JSON Response
    │       ↓
    │   CustomerData returned
    │
    ├─→ ScreenPopService.onIncomingCall()
    │       ↓
    │   URL template + placeholders
    │       ↓
    │   launchUrl() or http.get()
    │
    └─→ ActiveCall updated with customer data
            ↓
        IncomingCallPopup shows customer info
```

### 4.3 Configuration Schema

```dart
class IntegrationSettings {
  // Customer Lookup
  String customerLookupUrl;          // Template: ?number=%NUMBER%
  Duration customerLookupTimeout;
  bool customerLookupEnabled;
  
  // Screen Pop
  String screenPopUrl;               // Template: ?phone=%NUMBER%
  String screenPopEvent;             // 'ring' or 'answer'
  bool screenPopOpenBrowser;         // true = browser, false = HTTP
  bool screenPopSuppressWindow;      // Suppress main window
  
  // Call Logging
  String callEndWebhookUrl;
  bool callEndWebhookEnabled;
  
  // Recording Upload
  String recordingUploadUrl;
  String recordingFileFieldName;
  bool recordingUploadEnabled;
  
  // Clipboard
  bool clipboardMonitoringEnabled;
  Duration clipboardPollInterval;
  
  // Dialing Rules
  List<DialingRule> dialingRules;
  
  // Caller ID Transformation
  List<CallerIdTransformation> callerIdTransformations;
}
```

### 4.4 Named Pipe API Extensions

**New Commands:**
```json
// Transfer call
{ "type": "CallTransfer", "payload": { "call_id": 1, "dest_uri": "sip:100@domain" } }

// Send DTMF
{ "type": "CallDtmf", "payload": { "digits": "*100#" } }

// Set status
{ "type": "SetPresence", "payload": { "status": "Away" } }

// Start recording
{ "type": "StartRecording", "payload": { "call_id": 1, "path": "C:\\recordings" } }

// Stop recording
{ "type": "StopRecording", "payload": { "call_id": 1 } }
```

**New Events:**
```json
// Customer data received
{ "type": "CustomerDataReceived", "payload": { "call_id": 1, "name": "John Doe", "company": "ACME" } }

// Recording started
{ "type": "RecordingStarted", "payload": { "call_id": 1, "path": "C:\\rec.wav" } }

// Recording stopped
{ "type": "RecordingStopped", "payload": { "call_id": 1, "duration_secs": 120 } }
```

---

## 5. Security Considerations

### 5.1 Credential Storage

**Current:** In-memory only (per README limitations)

**Recommendations:**
- Use Windows Credential Manager for webhook URLs with authentication
- Support for API keys in URLs (encrypted storage)
- Never log full URLs with credentials

### 5.2 HTTPS Enforcement

**Requirements:**
- Default to HTTPS for all webhooks
- Certificate validation enabled
- Option to disable for self-signed certs (development only)

### 5.3 Input Validation

**Critical Areas:**
- URL templates: Validate against injection attacks
- Regex patterns: Prevent ReDoS attacks
- File paths: Sanitize recording upload paths
- CLI parameters: Validate phone number formats

### 5.4 Privacy Considerations

**Data Handling:**
- Customer data cached only in memory (not persisted)
- Call recordings encrypted at rest (future enhancement)
- Webhook payloads logged with sensitive data masked

---

## 6. Testing Strategy

### 6.1 Unit Tests

**Services:**
```dart
// dialing_rules_service_test.dart
test('transforms number with pattern matching', () {
  final service = DialingRulesService();
  service.addRule(DialingRule(
    pattern: r'^\+1(\d{10})$',
    replacement: r'001\1',
  ));
  expect(service.transform('+12345678900'), '0012345678900');
});

// customer_lookup_service_test.dart
test('parses JSON response correctly', () async {
  final service = CustomerLookupService();
  final data = await service.lookup('+12345678900');
  expect(data.contactName, 'John Doe');
  expect(data.company, 'ACME Corp');
});
```

### 6.2 Integration Tests

**Webhook Testing:**
```dart
test('sends webhook on incoming call', () async {
  // Mock HTTP client
  // Trigger incoming call event
  // Verify HTTP GET request sent
  // Verify URL contains correct placeholders
});
```

**CLI Testing:**
```powershell
# Automated CLI test script
pd dial 100;extid=123456
pd dtmf *100#
pd transfer 200
pd status Away
```

### 6.3 Manual Testing Checklist

**CRM Integration:**
- [ ] Incoming call triggers customer lookup
- [ ] Customer data displayed in popup
- [ ] "Open CRM" button works
- [ ] Screen pop opens browser
- [ ] Background HTTP screen pop works
- [ ] extid parameter passed through

**Clipboard:**
- [ ] Clipboard monitoring detects phone numbers
- [ ] Popup appears in bottom-right
- [ ] Number can be edited before dialing
- [ ] Dial button initiates call

**Recording:**
- [ ] Recording starts on call answer
- [ ] Recording stops on call end
- [ ] File saved to correct location
- [ ] Upload to web server works
- [ ] Metadata included in upload

**CLI:**
- [ ] All commands work from PowerShell
- [ ] Parameters parsed correctly
- [ ] Error messages displayed
- [ ] Exit codes correct

---

## 7. Documentation Requirements

### 7.1 User Documentation

**New Pages:**
- `docs/integration-crm.md` - CRM integration setup
- `docs/click-to-call.md` - URI scheme configuration
- `docs/clipboard-monitoring.md` - Clipboard auto-dial
- `docs/call-recording.md` - Recording setup & upload
- `docs/dialing-rules.md` - Number transformation
- `docs/cli-reference.md` - Complete CLI command reference

### 7.2 Developer Documentation

**API Reference:**
- Extended Named Pipe API documentation
- Webhook payload schema
- Customer lookup JSON format
- Recording upload API specification

### 7.3 Migration Guide

**For Existing Users:**
- Settings migration for new integration options
- Backward compatibility notes
- Upgrade procedure

---

## Appendix A: Complete Feature Comparison

| Feature | Softphone.pro | PacketDial Current | PacketDial Planned |
|---------|---------------|-------------------|-------------------|
| **CLI Commands** |
| `-call` | ✅ | ✅ (dial) | ✅ (enhanced) |
| `-transfer` | ✅ | ❌ | ✅ Phase 1 |
| `-answer` | ✅ | ✅ | ✅ |
| `-hangup` | ✅ | ✅ | ✅ |
| `-dtmf` | ✅ | ❌ | ✅ Phase 1 |
| `-setstatus` | ✅ | ❌ | ✅ Phase 1 |
| `-close` | ✅ | ❌ | ✅ Phase 1 |
| **URI Schemes** |
| `tel:` | ✅ | ✅ | ✅ |
| `callto:` | ✅ | ❌ | ✅ Phase 1 |
| `sip:` | ✅ | ✅ | ✅ |
| `extid` param | ✅ | ❌ | ✅ Phase 1 |
| `sip_id` param | ✅ | ❌ | ✅ Phase 1 |
| **CRM Integration** |
| Customer lookup | ✅ | ❌ | ✅ Phase 2 |
| Screen pop (browser) | ✅ | ❌ | ✅ Phase 2 |
| Screen pop (HTTP) | ✅ | ✅ | ✅ Phase 2 |
| Call logging | ✅ | ✅ | ✅ Phase 2 |
| **Clipboard** |
| Auto-monitoring | ✅ | ❌ | ✅ Phase 3 |
| Hotkey dialing | ❌ | ✅ | ✅ |
| **Recording** |
| Call recording | ✅ | ❌ | ✅ Phase 3 |
| HTTP upload | ✅ | ❌ | ✅ Phase 3 |
| **Advanced** |
| Dialing rules | ✅ | ❌ | ✅ Phase 1 |
| Regex transformation | ✅ | ❌ | ✅ Phase 4 |
| DID number support | ✅ | ❌ | ✅ Phase 4 |
| Window suppression | ✅ | ❌ | ✅ Phase 4 |

---

## Appendix B: Timeline Summary

| Phase | Duration | Features |
|-------|----------|----------|
| **Phase 1: Foundation** | Weeks 1-2 | CLI extensions, URI parsing, dialing rules |
| **Phase 2: CRM Integration** | Weeks 3-4 | Customer lookup, screen pop, placeholders |
| **Phase 3: Clipboard & Recording** | Weeks 5-6 | Clipboard monitoring, call recording, upload |
| **Phase 4: Advanced** | Weeks 7-8 | Regex, DID support, window suppression |

**Total Estimated Duration:** 8 weeks

---

## Appendix C: Dependencies to Add

**pubspec.yaml:**
```yaml
dependencies:
  url_launcher: ^9.0.0          # Screen pop browser launch
  regex: ^0.1.0                 # Regex transformations (if needed)
  path: ^1.9.0                  # File path utilities
  windows_credential_manager: ^1.0.0  # Secure credential storage
  
dev_dependencies:
  mockito: ^5.4.0               # Testing mocks
```

**vcpkg packages:**
```
pjsip[recording]
```

**Rust crates:**
```toml
[dependencies]
regex = "1.10"
windowsCredentialManager = "0.1"
```

---

## Conclusion

This implementation plan provides a comprehensive roadmap for integrating all Softphone.pro features into PacketDial. The phased approach ensures steady progress while maintaining code quality and test coverage. Key architectural decisions prioritize modularity, security, and extensibility for future enhancements.

**Next Steps:**
1. Review and approve implementation plan
2. Create GitHub issues for each phase
3. Set up project milestones
4. Begin Phase 1 development
