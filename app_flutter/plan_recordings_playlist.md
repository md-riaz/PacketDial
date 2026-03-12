# Recordings Playlist Page Implementation Plan

## Overview
Add a recordings playlist page accessible from the Dialer page that allows users to browse, play, and manage their call recordings using the existing `just_audio` package.

**Key Integration Point**: This feature builds on top of the existing **Local Call Recording** feature, which automatically saves call recordings to disk. The playlist page will display all recordings created by:
- Automatic call recording (when enabled in Settings)
- Manual recording started/stopped during calls via `RecordingService`

---

## 1. File Structure

Create the following new files:

```
app_flutter/lib/
├── screens/
│   └── recordings_screen.dart          # Main recordings playlist page
├── widgets/
│   └── recording_list_tile.dart        # Reusable recording item widget
│   └── audio_player_controls.dart      # Playback control widget
├── providers/
│   └── recordings_provider.dart        # Riverpod provider for recordings state
└── models/
    └── recording_item.dart             # Recording data model
```

---

## 1.5. Integration with Existing Local Call Recording Feature

### Current Architecture

The existing local call recording feature consists of:

1. **`RecordingService`** (`lib/core/recording_service.dart`)
   - Manages per-call recording sessions with `RecordingSession` objects
   - Tracks recording state: `idle` → `starting` → `recording` → `stopping` → `stopped`
   - Provides `getRecordings()` method that scans the recordings directory for `.wav` files
   - Already handles file persistence in organized directory structure:
     - `{RecordingsDir}/{YYYY}/{MM}/{callId}_{YYYYMMDD_HHMMSS}.wav`

2. **Auto-Recording** (Settings → Local Call Recording)
   - Controlled by `AppSettingsService.localCallRecordingEnabled`
   - When enabled, automatically starts recording when a call connects (`maybeAutoStartForCall`)
   - Uses `autoRequested: true` flag in `RecordingSession`

3. **Manual Recording**
   - Can be started/stopped during calls via `RecordingService.startRecordingForCall()` / `stopRecordingForCall()`
   - Used from dialer screen or call controls

4. **Engine Integration** (`lib/core/engine_channel.dart`)
   - Native engine handles actual audio capture
   - Sends events: `RecordingStarted`, `RecordingStopped`, `RecordingSaved`
   - `RecordingService` listens and updates session state

### How Playlist Page Integrates

```
┌─────────────────────────────────────────────────────────────────┐
│                    Call Recording Flow                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────┐   │
│  │ Auto Record  │────▶│  Recording   │────▶│   .wav File  │   │
│  │ (Setting ON) │     │   Session    │     │   on Disk    │   │
│  └──────────────┘     └──────────────┘     └──────────────┘   │
│                              │                       │         │
│                              │                       ▼         │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────┐   │
│  │ Manual Start │────▶│ RecordingSvc │────▶│  Playlist    │   │
│  │ (During Call)│     │ .getRecs()   │     │    Page      │   │
│  └──────────────┘     └──────────────┘     └──────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**The Playlist Page will:**
- Use `RecordingService.getRecordings()` to list all `.wav` files
- Display recordings from **both** auto and manual sources
- Show recording metadata (call ID, date, duration) from `RecordingSession` if available
- Allow playback of any saved recording using `just_audio`
- Support delete via `RecordingService.deleteRecording()`

### RecordingSession Integration

The playlist should leverage existing `RecordingSession` data:

```dart
// Get active/recent recording session for a call
final session = RecordingService.instance.sessionForCall(callId);
if (session != null) {
  // Access: filePath, phase, startedAt, endedAt, durationMs, autoRequested
  print('Recording: ${session.filePath}');
  print('Auto-recorded: ${session.autoRequested}');
  print('Duration: ${session.durationMs}ms');
}
```

### Settings Integration

The playlist page should respect existing settings:
- **Recording Directory**: `AppSettingsService.localRecordingDirectory`
- **Auto-Recording Toggle**: `AppSettingsService.localCallRecordingEnabled`

Consider adding a quick link from playlist page to recording settings.

---

## 2. Implementation Steps

### Step 1: Create Recording Data Model
**File**: `lib/models/recording_item.dart`

Create a data class to represent a recording with:
- File path
- File name (display name)
- File size
- Created date (extracted from filename or file metadata)
- Duration (if available from `RecordingSession.durationMs`)
- Call ID (extractable from filename)
- `autoRecorded` flag (from `RecordingSession.autoRequested`)
- `session` reference (optional link to active `RecordingSession`)

**Integration with RecordingService:**
```dart
class RecordingItem {
  final String filePath;
  final String fileName;
  final int callId;
  final DateTime createdAt;
  final int fileSizeBytes;
  final Duration? duration;
  final bool autoRecorded;
  final RecordingSession? session; // Link to active session

  RecordingItem({
    required this.filePath,
    required this.fileName,
    required this.callId,
    required this.createdAt,
    required this.fileSizeBytes,
    this.duration,
    this.autoRecorded = false,
    this.session,
  });

  /// Create from File (for existing recordings on disk)
  factory RecordingItem.fromFile(File file) {
    final fileName = p.basename(file.path);
    final match = RegExp(r'(\d+)_(\d{8}_\d{6})\.wav').firstMatch(fileName);

    if (match == null) return null;

    final callId = int.parse(match.group(1)!);
    final timestamp = match.group(2)!;
    final createdAt = _parseTimestamp(timestamp);

    // Check if there's an active session for this call
    final session = RecordingService.instance.sessionForCall(callId);

    return RecordingItem(
      filePath: file.path,
      fileName: fileName,
      callId: callId,
      createdAt: createdAt,
      fileSizeBytes: file.lengthSync(),
      duration: session?.durationMs != null
          ? Duration(milliseconds: session!.durationMs!)
          : null,
      autoRecorded: session?.autoRequested ?? false,
      session: session,
    );
  }

  static DateTime _parseTimestamp(String timestamp) {
    // Parse YYYYMMDD_HHMMSS format
    final year = int.parse(timestamp.substring(0, 4));
    final month = int.parse(timestamp.substring(4, 6));
    final day = int.parse(timestamp.substring(6, 8));
    final hour = int.parse(timestamp.substring(9, 11));
    final minute = int.parse(timestamp.substring(11, 13));
    final second = int.parse(timestamp.substring(13, 15));

    return DateTime(year, month, day, hour, minute, second);
  }
}
```

---

### Step 2: Create Recordings Provider
**File**: `lib/providers/recordings_provider.dart`

Create a Riverpod `StateNotifierProvider` to manage:
- List of recordings (loaded from `RecordingService.getRecordings()`)
- Current playback state (playing, paused, stopped)
- Currently playing recording
- Audio player state using `just_audio`
- **Integration with RecordingService listeners** for real-time updates

**Key Integration Points:**
- Listen to `RecordingService` change notifications
- When recording completes, refresh the playlist automatically
- Show currently recording items with live indicator

Provider should expose:
- `recordingsList` - List of all recordings
- `isLoading` - Loading state
- `currentRecording` - Currently selected recording
- `isPlaying` - Playback state
- `position` - Current playback position
- `duration` - Total recording duration
- `activeRecordingSession` - Currently active recording (if any)

**Example with RecordingService integration:**
```dart
class RecordingsNotifier extends StateNotifier<RecordingsState> {
  final AudioPlayer _player = AudioPlayer();

  RecordingsNotifier() : super(RecordingsState()) {
    // Listen to RecordingService changes
    RecordingService.instance.addListener(_onRecordingChanged);

    // Set up player state listeners
    _player.playerStateStream.listen((state) {
      state.notifier.updatePlaybackState(state);
    });
  }

  void _onRecordingChanged() {
    // Refresh list when recording starts/stops/completes
    loadRecordings();
  }

  Future<void> loadRecordings() async {
    state = state.copyWith(isLoading: true);

    final files = await RecordingService.instance.getRecordings();
    final items = files
        .map((f) => RecordingItem.fromFile(f))
        .whereType<RecordingItem>()
        .toList();

    state = state.copyWith(
      recordings: items,
      isLoading: false,
    );
  }

  @override
  void dispose() {
    RecordingService.instance.removeListener(_onRecordingChanged);
    _player.dispose();
    super.dispose();
  }
}
```

---

### Step 3: Create Audio Player Controls Widget
**File**: `lib/widgets/audio_player_controls.dart`

Create a reusable widget with:
- Play/Pause button
- Stop button
- Seek slider with position/duration display
- Volume control (optional)
- Playback speed control (optional)

Use `just_audio` methods:
- `player.play()` / `player.pause()` / `player.stop()`
- `player.positionStream` for progress
- `player.durationStream` for duration
- `player.seek()` for seeking

---

### Step 4: Create Recording List Tile Widget
**File**: `lib/widgets/recording_list_tile.dart`

Create a list tile widget displaying:
- Recording name/number
- Date and time
- Duration
- File size
- Play indicator (if currently playing)
- Context menu (delete, share, open location)

---

### Step 5: Create Recordings Screen
**File**: `lib/screens/recordings_screen.dart`

Main screen with:
- Header with "Recordings" title and refresh button
- Search/filter bar (optional)
- Recordings list (ListView.builder)
- Bottom sheet or expanded player controls
- Empty state when no recordings exist
- **Live recording indicator** for active recordings
- **Settings quick link** to recording configuration

Features:
- Pull-to-refresh to reload recordings
- Tap to play/pause
- Long-press for context menu
- Swipe-to-delete (with confirmation)
- **Auto-record badge** for recordings created by auto-recording feature
- **Live indicator** for currently recording calls

**RecordingService Integration UI:**
```dart
// Show badge if auto-recorded
if (recording.autoRecorded) {
  chips.add(Chip(
    label: const Text('Auto', style: TextStyle(fontSize: 10)),
    backgroundColor: AppTheme.primary.withOpacity(0.2),
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
  ));
}

// Show live indicator if currently recording
if (recording.session?.isActive == true) {
  widgets.add(Row(
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: AppTheme.errorRed,
          shape: BoxShape.circle,
        ),
      ),
      const SizedBox(width: 4),
      const Text('REC', style: TextStyle(
        color: AppTheme.errorRed,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      )),
    ],
  ));
}
```

---

### Step 6: Add Navigation from Dialer Screen
**File**: `lib/screens/dialer_screen.dart`

Add access to recordings from the dialer:

**Option A**: Add a button/icon in the dialer screen header or footer
```dart
IconButton(
  icon: const Icon(Icons.library_music),
  onPressed: () => _navigateToRecordings(context),
  tooltip: 'Recordings',
)
```

**Option B**: Add to the main navigation bar (replace or add to existing tabs)
Modify `lib/main.dart` to add a 6th tab for recordings.

**Option C**: Add as a submenu in dialer's overflow menu (if exists)

**Recommended**: Option A - Add a floating action button or icon in the dialer screen for quick access without changing the main navigation structure.

---

### Step 7: Update RecordingService (if needed)
**File**: `lib/core/recording_service.dart`

The existing `RecordingService` already has:
- ✅ `getRecordings()` - Returns `List<File>` of all recordings
- ✅ `deleteRecording(String path)` - Delete a recording
- ✅ `getRecordingsDir()` - Get recordings directory
- ✅ `sessionForCall(int callId)` - Get active session for a call
- ✅ `addListener()` / `removeListener()` - Change notification support

May need to add (optional enhancements):
- Method to get rich metadata including duration from engine
- Method to get all completed sessions (not just active)
- Export/import functionality (future)

---

### Step 8: Handle Active Recording Edge Cases

**Important**: The playlist must handle cases where:

1. **Recording in Progress**: A call is currently being recorded
   - Show live indicator
   - Display elapsed time if available from `session.startedAt`
   - Allow playback of completed recordings while recording continues

2. **Recording Just Completed**: File saved but session still active
   - Use `handleRecordingSaved` callback to refresh list
   - Update duration from `session.durationMs`

3. **Orphaned Files**: Files on disk without active session
   - Display normally without session metadata
   - Duration may be unknown until played

4. **Concurrent Recordings**: Multiple calls recording simultaneously
   - Show all active recordings with live indicators
   - Allow playback of any completed recording

**Edge Case Handling Example:**
```dart
// In recording list tile
Widget _buildDurationWidget(RecordingItem recording) {
  // If actively recording, show elapsed time
  if (recording.session?.isActive == true) {
    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (context, snapshot) {
        final elapsed = DateTime.now().difference(
          recording.session!.startedAt ?? DateTime.now(),
        );
        return Text(_formatDuration(elapsed));
      },
    );
  }

  // Otherwise show recorded duration
  if (recording.duration != null) {
    return Text(_formatDuration(recording.duration!));
  }

  return const Text('--:--');
}
```

---

## 3. Technical Details

### Using just_audio for Playback

```dart
import 'package:just_audio/just_audio.dart';

final player = AudioPlayer();

// Set audio source
await player.setFilePath(recordingPath);

// Play
await player.play();

// Pause
await player.pause();

// Stop
await player.stop();

// Seek
await player.seek(Duration(seconds: 30));

// Listen to position
player.positionStream.listen((position) {
  // Update UI
});

// Listen to completion
player.playerStateStream.listen((state) {
  if (state.processingState == ProcessingState.completed) {
    // Recording finished
  }
});
```

### Recording Filename Format
Based on `RecordingService.generateRecordingPath()`:
```
{callId}_{YYYYMMDD_HHMMSS}.wav
```
Example: `12345_20260312_143022.wav`

Parse this format to extract:
- Call ID
- Recording date/time

---

## 4. UI/UX Design Guidelines

Follow existing app theme (`lib/core/app_theme.dart`):
- Use dark theme colors
- Primary color: `AppTheme.primary`
- Surface colors: `AppTheme.surfaceCard`, `AppTheme.surfaceVariant`
- Text colors: `AppTheme.textPrimary`, `AppTheme.textSecondary`
- Call green: `AppTheme.callGreen` for play buttons
- Error red: `AppTheme.errorRed` for delete actions

---

## 5. Dependencies

No new dependencies required. Using existing:
- `just_audio: ^0.10.5` - Audio playback
- `flutter_riverpod` - State management
- `path_provider` - File paths
- `intl` - Date formatting
- `path` - Path manipulation

---

## 6. Testing Considerations

- Test with various recording file formats (.wav)
- Test playback controls (play, pause, stop, seek)
- Test with large number of recordings (performance)
- Test delete functionality with confirmation
- Test empty state (no recordings)
- Test navigation from dialer during active call
- Test audio focus/pausing when call comes in

---

## 7. Future Enhancements (Out of Scope)

- Recording sharing/export
- Cloud backup
- Recording transcription
- Bookmarking/favorites
- Playlist creation
- Recording renaming
- Search within recordings

---

## 8. Implementation Order

1. ✅ Create `recording_item.dart` model with RecordingService integration
2. ✅ Create `recordings_provider.dart` with RecordingService listener
3. ✅ Create `audio_player_controls.dart` widget
4. ✅ Create `recording_list_tile.dart` with auto-record badge and live indicator
5. ✅ Create `recordings_screen.dart` page with edge case handling
6. ✅ Add navigation from dialer screen
7. ✅ Test with auto-recording feature
8. ✅ Test with manual recording feature
9. ✅ Test edge cases (active recording, completed, orphaned files)
10. ✅ Polish UI and add settings link

---

## 9. Local Call Recording Feature Integration Summary

### Data Flow

```
User enables "Local Call Recording" in Settings
              │
              ▼
┌─────────────────────────────┐
│  AppSettingsService         │
│  .localCallRecordingEnabled │
└─────────────────────────────┘
              │
              ▼
┌─────────────────────────────┐
│  EngineChannel              │
│  (listens to call events)   │
└─────────────────────────────┘
              │
              ▼ (when call connects)
┌─────────────────────────────┐
│  RecordingService           │
│  .maybeAutoStartForCall()   │
└─────────────────────────────┘
              │
              ▼
┌─────────────────────────────┐
│  Native Engine              │
│  (captures audio to file)   │
└─────────────────────────────┘
              │
              ▼ (when complete)
┌─────────────────────────────┐
│  .wav file saved to:        │
│  {RecordingsDir}/{YYYY}/    │
│  {MM}/{callId}_{ts}.wav     │
└─────────────────────────────┘
              │
              ▼
┌─────────────────────────────┐
│  Recordings Playlist Page   │
│  - Scans directory          │
│  - Displays all recordings  │
│  - Plays via just_audio     │
│  - Shows live indicators    │
└─────────────────────────────┘
```

### Key Integration Points

| Feature | Integration Point |
|---------|------------------|
| **Auto-recorded files** | `RecordingSession.autoRequested` flag |
| **Manual recordings** | Same pipeline, `autoRequested = false` |
| **Live recording status** | `RecordingSession.isActive` + listeners |
| **Recording duration** | `RecordingSession.durationMs` |
| **File location** | `RecordingService.getRecordingsDir()` |
| **File listing** | `RecordingService.getRecordings()` |
| **Delete** | `RecordingService.deleteRecording()` |
| **Real-time updates** | `RecordingService.addListener()` |

### Settings Page Reference

Users can configure recordings in:
- **Settings → Local Call Recording** (toggle)
- **Settings → Local Recording Directory** (path)

Consider adding a "Open Recordings Folder" button and "Manage Recordings" link from settings to the playlist page.

---

## 10. Code Snippets

### Recording Item Model Template (with RecordingService Integration)
```dart
class RecordingItem {
  final String filePath;
  final String fileName;
  final int callId;
  final DateTime createdAt;
  final int fileSizeBytes;
  final Duration? duration;
  final bool autoRecorded;
  final RecordingSession? session; // Link to active session

  RecordingItem({
    required this.filePath,
    required this.fileName,
    required this.callId,
    required this.createdAt,
    required this.fileSizeBytes,
    this.duration,
    this.autoRecorded = false,
    this.session,
  });

  /// Create from File (for existing recordings on disk)
  factory RecordingItem.fromFile(File file) {
    final fileName = p.basename(file.path);
    final match = RegExp(r'(\d+)_(\d{8}_\d{6})\.wav').firstMatch(fileName);

    if (match == null) return null;

    final callId = int.parse(match.group(1)!);
    final timestamp = match.group(2)!;
    final createdAt = _parseTimestamp(timestamp);

    // Check if there's an active session for this call
    final session = RecordingService.instance.sessionForCall(callId);

    return RecordingItem(
      filePath: file.path,
      fileName: fileName,
      callId: callId,
      createdAt: createdAt,
      fileSizeBytes: file.lengthSync(),
      duration: session?.durationMs != null
          ? Duration(milliseconds: session!.durationMs!)
          : null,
      autoRecorded: session?.autoRequested ?? false,
      session: session,
    );
  }

  static DateTime _parseTimestamp(String timestamp) {
    // Parse YYYYMMDD_HHMMSS format
    final year = int.parse(timestamp.substring(0, 4));
    final month = int.parse(timestamp.substring(4, 6));
    final day = int.parse(timestamp.substring(6, 8));
    final hour = int.parse(timestamp.substring(9, 11));
    final minute = int.parse(timestamp.substring(11, 13));
    final second = int.parse(timestamp.substring(13, 15));

    return DateTime(year, month, day, hour, minute, second);
  }
}
```

---

## 11. Navigation Implementation

### In `dialer_screen.dart`:
```dart
void _navigateToRecordings() {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => const RecordingsScreen(),
    ),
  );
}
```

Add a button in the dialer screen (suggested location: top-right corner near existing action buttons, or as a floating action button).

---

## Summary

This plan adds a recordings playlist page using the existing `just_audio` package, maintaining consistency with the current app architecture and design system. The feature provides users with easy access to their call recordings directly from the dialer screen.

**Key Integration with Local Call Recording:**
- Builds on existing `RecordingService` infrastructure
- Displays both auto-recorded and manually recorded calls
- Shows live recording indicators for active sessions
- Respects existing recording directory and enable/disable settings
- Uses `RecordingSession` data for duration, timestamps, and metadata
- Automatically refreshes when recordings complete via ChangeNotifier
