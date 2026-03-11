# Spec: Single-File Local Call Recording for Flutter + Rust + PJSIP

## 1) Goal

Implement **local call recording** for a Flutter app that uses a Rust SIP core backed by **PJSIP/PJSUA2**.

The user-facing behavior is simple:

* user taps **Start Recording**
* app saves **one mixed call recording file**
* file contains **both local microphone audio and remote party audio**
* user taps **Stop Recording** or recording stops automatically when call ends
* recording is stored locally and exposed to Flutter as a normal file path

The recording must be done in the **Rust/PJSIP media layer**, not in Flutter. PJSIP’s audio model is built around a **conference bridge** where sources transmit to sinks, and if multiple sources transmit to the same sink, the audio is mixed. `AudioMediaRecorder` records to a WAV file, and valid call audio media is available when the call media becomes active via `onCallMediaState()`. ([docs.pjsip.org][1])

---

## 2) Non-goals

This spec does **not** require:

* separate local/remote track files
* server-side recording
* OS-level speaker capture
* Flutter plugins that record device audio directly
* recording before call media is active

Those approaches are either the wrong layer or a reliability trap with extra goblin energy.

---

## 3) Core Design Rule

## Recording ownership

**Flutter is control plane only.**
**Rust + PJSIP is media plane.**

Flutter may:

* show recording UI
* send commands to start/stop recording
* display saved file info

Flutter must **not**:

* attempt to capture the VoIP call audio itself
* mix device mic and speaker audio in Dart
* rely on general-purpose audio recorder plugins for call media

Reason: the call audio is already inside the PJSIP media graph. PJSIP exposes media ports and allows sources to transmit to destinations. The recorder is just another sink in the conference bridge. ([docs.pjsip.org][1])

---

## 4) Functional Requirements

## FR-1: Single mixed recording file

System shall produce exactly **one recording file per recording session**.

Content:

* local microphone audio
* remote call audio
* mixed into one file by the PJSIP conference bridge

Implementation rule:

* connect **mic media -> recorder**
* connect **call audio media -> recorder**

Because multiple sources to one destination are mixed by the conference bridge, this produces a single mixed recording. ([docs.pjsip.org][1])

---

## FR-2: Start only after call media is active

Recording shall only start after the call has valid active audio media.

Implementation rule:

* gate recording setup behind `Call::onCallMediaState()`
* only call `getAudioMedia()` when media is active/ready

PJSIP documents that `getAudioMedia()` is valid only when the call audio media state is ready or active, and media state changes are reported via `onCallMediaState()`. ([docs.pjsip.org][2])

---

## FR-3: User controls

Flutter shall expose:

* `Start Recording`
* `Stop Recording`
* recording indicator while active

Optional:

* auto-record per app setting
* elapsed duration display

---

## FR-4: Saved file path returned to Flutter

When recording stops successfully, Rust shall return metadata to Flutter:

```text
recording_id
call_id
absolute_file_path
started_at
ended_at
duration_ms
file_size_bytes
format
status
```

---

## FR-5: Proper file finalization

Recorder shall be properly stopped and destroyed so the output file is valid.

PJSIP’s recorder writes WAV output, and the docs warn that the WAV file may look corrupt if the app does not quit or close properly because the header information is not finalized correctly. Also, stopping transmission alone does not close the WAV file. ([pjsip.org][3])

Implementation rule:

* stop transmit links
* release/destroy recorder object
* only then report success

---

## 5) Engineering Trick: Media Stabilization Delay

This is the subtle engineering trick.

### Requirement

After media becomes active, the system shall wait a **short configurable stabilization delay** before creating transmit links to the recorder.

### Default

* `recording_start_delay_ms = 300`

### Why

In real devices and real networks, the media graph can be technically “active” a hair before everything is fully settled:

* device route may still be switching
* jitter buffer may be warming up
* audio path may still be attaching
* first packets may arrive unevenly
* beginning of recording may clip or contain a short pop/silence

This delay is **not** a PJSIP protocol requirement. It is an **implementation heuristic** to improve real-world reliability.

### Rule

* when user requests recording before media is ready, mark intent as `pending_start`
* once `onCallMediaState()` reports active audio, start a one-shot timer
* after delay expires, verify media is still active
* then attach recorder links

### Constraints

* configurable from Rust core config
* min 0 ms
* recommended range 150 to 500 ms
* default 300 ms

### Acceptance criteria

* first 300 to 500 ms of speech is not clipped in normal startup conditions
* recording never starts before media is active
* if call ends during delay window, no recorder file is created unless policy says to create empty file

That tiny delay looks trivial. It is not trivial. It is the difference between “works on my phone” and “why does the first hello disappear on Samsung Tuesdays.”

---

## 6) Architecture

```text
Flutter UI
  └─ Recording button / indicator
      └─ FFI command
          └─ Rust SIP Core
              └─ CallSession manager
                  └─ PJSIP/PJSUA2 media objects
                      ├─ Capture device media (mic)
                      ├─ Call audio media
                      └─ AudioMediaRecorder (WAV sink)
```

### Responsibilities

## Flutter

* button taps
* permissions UX
* display recording state
* file list / playback UI

## Rust

* recording state machine
* file path generation
* recorder lifecycle
* timer for stabilization delay
* error handling
* FFI events back to Flutter

## PJSIP

* actual audio routing
* conference bridge mixing
* WAV recording

---

## 7) State Machine

```text
Idle
  -> PendingStart
  -> Starting
  -> Recording
  -> Stopping
  -> Stopped
  -> Failed
```

### Transitions

## Idle -> PendingStart

User presses Start Recording, but media is not active yet.

## PendingStart -> Starting

`onCallMediaState()` reports active audio, stabilization timer begins.

## Starting -> Recording

Timer expires, media still active, recorder created, transmit links attached.

## Recording -> Stopping

User presses stop, call disconnects, hold policy disables recording, or fatal media error.

## Stopping -> Stopped

Links removed, recorder destroyed, metadata flushed.

## Any -> Failed

Recorder create/connect/finalize failure.

---

## 8) Rust Core Interfaces

Recommended FFI surface:

```rust
start_call_recording(call_id: i32) -> Result<RecordingStartAck, RecordingError>
stop_call_recording(call_id: i32) -> Result<RecordingStopResult, RecordingError>
get_call_recording_state(call_id: i32) -> RecordingState
set_auto_record(enabled: bool) -> Result<(), RecordingError>
set_recording_directory(path: String) -> Result<(), RecordingError>
set_recording_start_delay_ms(delay_ms: u32) -> Result<(), RecordingError>
```

### Event callbacks to Flutter

```rust
on_recording_state_changed(call_id, state)
on_recording_saved(call_id, path, duration_ms, file_size_bytes)
on_recording_error(call_id, code, message)
```

---

## 9) Internal Rust Data Model

```rust
enum RecordingState {
    Idle,
    PendingStart,
    Starting,
    Recording,
    Stopping,
    Stopped,
    Failed,
}

struct RecordingConfig {
    root_dir: PathBuf,
    auto_record: bool,
    start_delay_ms: u32, // default 300
    create_empty_file_on_abort: bool,
}

struct RecordingSession {
    call_id: i32,
    state: RecordingState,
    file_path: PathBuf,
    started_at: Option<SystemTime>,
    ended_at: Option<SystemTime>,
    pending_start: bool,
    recorder_handle: Option<RecorderHandle>,
}
```

`RecorderHandle` is your wrapper over the PJSUA2 `AudioMediaRecorder` plus any port references needed for cleanup.

---

## 10) PJSIP Recording Procedure

## Start sequence

1. Validate call exists.
2. Validate call is not already recording.
3. If call media not active:

   * set state to `PendingStart`
   * return ack to Flutter
4. If call media active:

   * enter `Starting`
   * wait `start_delay_ms`
   * re-check media state
   * obtain:

     * capture device media
     * call audio media
   * create `AudioMediaRecorder` with target WAV path
   * connect:

     * mic -> recorder
     * call -> recorder
   * set state `Recording`

PJSIP’s audio conference bridge allows connecting source media to destination media, and the recorder is a WAV sink. Multiple sources transmitted to one sink are mixed. ([docs.pjsip.org][1])

## Stop sequence

1. If not recording, return benign no-op or typed error by policy.
2. Enter `Stopping`
3. disconnect:

   * mic -> recorder
   * call -> recorder
4. destroy/release recorder object
5. stat file
6. finalize metadata
7. set state `Stopped`
8. notify Flutter

---

## 11) Pseudocode

```text
onStartRecording(callId):
    session = getCallSession(callId)

    if session.recording.state in [Starting, Recording, PendingStart]:
        return AlreadyRecording

    if !session.media.isActive():
        session.recording.state = PendingStart
        session.recording.pending_start = true
        emit stateChanged(PendingStart)
        return Ok

    beginRecordingWithDelay(callId)
```

```text
onCallMediaState(callId):
    session = getCallSession(callId)

    if session.recording.pending_start && session.media.isActive():
        beginRecordingWithDelay(callId)
```

```text
beginRecordingWithDelay(callId):
    session.recording.state = Starting
    emit stateChanged(Starting)

    wait config.start_delay_ms

    if !session.media.isActive():
        session.recording.state = PendingStart
        return

    path = buildRecordingPath(callId)
    recorder = createRecorder(path)
    mic = getCaptureDevMedia()
    callAudio = getCallAudioMedia(callId)

    mic.startTransmit(recorder)
    callAudio.startTransmit(recorder)

    session.recording.recorder_handle = recorder
    session.recording.file_path = path
    session.recording.started_at = now()
    session.recording.pending_start = false
    session.recording.state = Recording
    emit stateChanged(Recording)
```

```text
onStopRecording(callId):
    session = getCallSession(callId)

    if session.recording.state not in [Recording, Starting, PendingStart]:
        return NotRecording

    session.recording.pending_start = false

    if session.recording.state == Recording:
        mic.stopTransmit(recorder)
        callAudio.stopTransmit(recorder)

    destroy recorder
    session.recording.ended_at = now()
    session.recording.state = Stopped
    emit recordingSaved(...)
```

---

## 12) File Format and Storage

## Required format

* `.wav`

PJSIP `AudioMediaRecorder` records WAV output. ([pjsip.org][3])

## File naming convention

```text
{call_id}_{yyyyMMdd_HHmmss}.wav
```

Example:

```text
98421_20260311_213455.wav
```

## Directory convention

```text
/app-data/recordings/YYYY/MM/
```

Example:

```text
/app-data/recordings/2026/03/98421_20260311_213455.wav
```

## Metadata sidecar

Optional JSON sidecar:

```json
{
  "call_id": 98421,
  "path": "/app-data/recordings/2026/03/98421_20260311_213455.wav",
  "started_at": "2026-03-11T21:34:55Z",
  "ended_at": "2026-03-11T21:40:12Z",
  "duration_ms": 317000,
  "status": "completed"
}
```

---

## 13) Flutter UI Spec

## Controls

* Start Recording button
* Stop Recording button
* Red recording indicator
* elapsed timer
* snackbar/toast on save or failure

## States

* Not recording
* Waiting for media
* Starting recording
* Recording
* Saving
* Failed

## UX rules

When user taps Start before media is active:

* show `Preparing recording…`

When recording becomes active:

* show timer + active indicator

When stopped:

* show saved file path or open/play action

Flutter must treat recording as a **commanded native capability**, not as a Dart-side audio feature.

---

## 14) Error Handling

Typed errors:

```text
CallNotFound
MediaNotReady
AlreadyRecording
RecorderCreateFailed
RecorderConnectFailed
RecorderFinalizeFailed
StorageUnavailable
PermissionDenied
CallEnded
InternalError
```

### Policies

## If call ends while PendingStart

* cancel pending start
* no file created by default

## If call ends while Recording

* stop and finalize immediately
* save partial file

## If recorder creation fails

* state -> Failed
* emit error to Flutter
* call audio continues normally

## If stop is called twice

* second call is idempotent no-op or typed benign error

---

## 15) Hold / Resume Policy

Recommended default:

* **continue recording only while active two-way audio exists**
* on hold:

  * stop current recording session, or
  * keep session open but expect silence

Cleaner default for users:

* keep recording file open unless call disconnects
* accept silence during hold

Alternative stricter policy:

* pause/resume at app layer and annotate metadata

This is product policy, not a PJSIP requirement.

---

## 16) Threading / Lifetime Rules

* all PJSIP media operations must run on the SIP/media thread expected by your integration model
* Flutter FFI must never directly touch native recorder objects
* recorder handle ownership belongs to Rust call session manager
* cleanup must occur on:

  * stop command
  * call disconnect
  * account shutdown
  * app termination path

Because `AudioMedia` and recorder participation are bridge-linked resources, lifetime mistakes here produce exactly the kind of bugs engineers describe as “haunted.”

---

## 17) Security and Privacy

Implementation shall support:

* explicit user action or explicit auto-record setting
* visible in-call recording indicator
* local-only storage by default
* app-private storage location where platform permits
* deletion API for recordings

Legal compliance varies by jurisdiction. The app should not sneak around like a trench-coated raccoon.

---

## 18) Acceptance Tests

## AT-1 Manual start after connect

* place call
* wait for active media
* tap Start Recording
* speak from both sides
* tap Stop
* resulting file exists and contains both voices

## AT-2 Manual start before media active

* user taps Start immediately after dialing
* state becomes `PendingStart`
* once media activates and delay expires, recording starts
* file contains conversation from that point onward

## AT-3 Engineering trick validation

* use default 300 ms delay
* verify beginning of recording is not clipped in common device scenarios
* compare against 0 ms baseline in internal QA

## AT-4 Call ends during recording

* recording auto-stops
* file finalizes successfully
* metadata duration is non-zero

## AT-5 Duplicate start

* second start request while recording returns `AlreadyRecording`
* original recording remains stable

## AT-6 Stop while pending

* pending timer canceled
* no recorder object leaked
* no bogus file created by default

## AT-7 File validity

* saved WAV opens in standard media player
* duration approximately matches call segment
* header not corrupt

The WAV validity requirement aligns with PJSIP guidance that proper close/shutdown is needed so the header is correct. ([docs.pjsip.org][4])

---

## 19) Recommended Defaults

```text
auto_record = false
format = wav
start_delay_ms = 300
create_empty_file_on_abort = false
directory = app-private recordings folder
```

---

## 20) Summary for Agents

### Implement this

* Flutter sends start/stop recording commands
* Rust owns recording lifecycle
* PJSIP conference bridge performs audio mixing
* one `AudioMediaRecorder` per recording session
* connect mic and call media to the same recorder
* only start after media is active
* add configurable 300 ms stabilization delay
* stop links and destroy recorder to finalize file

### Do not implement this

* Flutter-side audio capture
* separate local/remote files
* speaker-output recording hacks
* recording before valid call audio media exists

---

## 21) Minimal Implementation Checklist

* [ ] FFI start/stop API
* [ ] call session recording state machine
* [ ] pending-start support
* [ ] `onCallMediaState()` hook
* [ ] stabilization timer
* [ ] recorder create/connect/disconnect/destroy
* [ ] local file path generator
* [ ] Flutter state updates
* [ ] WAV validation test
* [ ] disconnect cleanup path

If you want this turned into a **handoff-ready engineering doc with Rust trait definitions, FFI signatures, and QA test matrix**, I can format it like a real implementation spec for your agent workflow.

[1]: https://docs.pjsip.org/en/latest/pjsua2/using/media_audio.html?utm_source=chatgpt.com "Working with audio media — PJSIP Project 2.16-dev documentation"
[2]: https://docs.pjsip.org/en/latest/pjsua2/using/call.html?utm_source=chatgpt.com "Calls — PJSIP Project 2.16-dev documentation"
[3]: https://pjsip.org/pjsip/docs/html/classpj_1_1AudioMediaRecorder.htm?utm_source=chatgpt.com "pj::AudioMediaRecorder Class Reference (2.13) - pjsip.org"
[4]: https://docs.pjsip.org/en/latest/specific-guides/audio-troubleshooting/problems/how_to_record.html?utm_source=chatgpt.com "How to record audio with pjsua — PJSIP Project 2.16-dev documentation"
