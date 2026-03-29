# PacketDial Features

Current high-level feature set as implemented in the active app.

## Calling

- Outgoing calls from the dialer
- Incoming call banner and dialer takeover
- Hold and mute
- DTMF send and local DTMF playback
- Blind transfer
- Attended transfer flow
- 3-way conference merge
- Multi-account registration and outgoing account selection
- Footer and in-call status updates

## Call History

- Local call history persisted by Flutter
- Answered, outgoing, incoming, missed, and duration-aware history entries
- History screen in the main tab shell

## Contacts and Presence

- Local contact list with JSON persistence
- BLF subscription and presence updates
- Presence filtering
- Extension-aware matching for BLF targets
- Dynamic contact actions such as call extension, call primary target, edit, and delete
- Contact import/export JSON support

## Settings

### Call settings

- Global DND
- Global auto answer
- Global DTMF method
- Local call recording toggle
- Local recording folder selection

### Audio settings

- Audio device enumeration
- Input/output selection

### Codec settings

- Global codec priority and enable/disable behavior

### Integration settings

- ring and end webhooks
- customer lookup
- screen pop
- clipboard monitoring
- recording upload

Note: settings import/export is not part of the active settings UI.

## Recording

- Per-call manual recording actions
- App-level auto-record setting
- Native WAV recording through PJSIP
- Default recording fallback to `Desktop\Recordings`

## Accounts

- Multiple accounts
- Auto-register on startup
- Account-friendly labels in the dialer and incoming call banner
- Forwarding
- Lookup URL
- codec/DTMF/auto-answer settings exposed through engine commands

## Diagnostics and Operations

- engine log buffer
- SIP message capture
- diagnostics screen
- network reachability indicator in footer

## Packaging

- Windows portable ZIP
- Windows installer
- release automation through GitHub Actions

## Window and Layout

- Minimum window size enforced at OS level (400×750) — cannot be dragged below this
- Resize lock toggle in title bar — pins window to current size, persisted across restarts, defaults to locked
- Content centered at fixed width — stretching the window wide shows background space, layout never breaks
- Saved window geometry clamped to minimum on restore — prevents undersized window from previous session
- Full title bar drag area — icon and app name are draggable, not just the empty space

## Known Current Gaps

- Windows Credential Manager is not the active password storage path yet
- multi-live-call UX is still limited compared with the native engine capability
- audio hot-swap still needs more hardening
