# Changelog

## Unreleased

---

## 1.0.3

### Added
- Responsive window layout — app content is constrained to a fixed width and centered in the window; stretching the window wide shows background space rather than breaking the layout (same behavior as MicroSIP)
- Window resize lock toggle in the title bar (lock icon) — when locked the OS window is pinned to its current size so users cannot accidentally resize; persisted across restarts and defaults to locked
- Minimum window size enforced at the OS level (`400×750`) — the window physically cannot be dragged below this size; enforced before geometry restore so it is active from the very first frame
- Snap-back guard in `onWindowResized` — if the window somehow ends up below the minimum (e.g. bitsdojo/window_manager disagreement) it is immediately snapped back to the minimum
- Saved geometry is clamped to the minimum on restore — prevents a previously-saved undersized window from being applied on next launch
- Title bar drag area now covers the icon and app name — the entire left portion of the title bar is draggable, not just the empty space to the right of the title

### Fixed
- Dialer screen overflow — replaced `Expanded` children inside the main column with `SingleChildScrollView` + fixed/constrained heights so the layout never throws a Flutter overflow error when the window is short
- Window could be restored to an arbitrarily large width from a previous session, causing the numpad and content to stretch and break; geometry restore now clamps width and height to valid bounds

---

## 0.5.0

### Added
- Full light mode theme — all screens, dialogs, widgets, and the numpad respond to system/app theme brightness; light mode uses genuine white/near-white surfaces with deep indigo primary color for proper contrast; `AppColorSet` exported so widget helpers can accept it as a parameter
- Publish Presence (SIP PUBLISH) — per-account toggle; when enabled the app sends SIP PUBLISH so subscribed contacts can see your status via BLF; requires server-side support (e.g. Asterisk `res_pjsip_publish_asterisk`, FreeSWITCH `mod_presence`)
- Microphone amplification toggle — disabled by default; when enabled applies 2× software gain via `pjsua_conf_adjust_tx_level` on the conference bridge mic port
- Echo cancellation toggle in app settings — enabled by default (200 ms tail); calls `pjsua_set_ec` at runtime so no restart needed
- DTMF method "Auto" — uses RFC2833 by default, automatically falls back to in-band audio if the remote side rejects RFC2833; now the default setting (previously RFC2833)
- BLF call pickup — when a contact is Ringing, its avatar blinks; double-click or use the "Call Pickup" context menu item to dial `**<extension>` (directed call pickup, compatible with Asterisk `Pickup()` and FreeSWITCH)
- BLF presence per-contact domain selection — pick an account when adding/editing a contact to set the subscribe domain; domain is used for event matching, not account ID
- Full BLF presence state set: Available, Busy, Ringing, Away, Offline, Error (previously only Unknown/Available/Busy)
- Call quality indicator — a small green/amber/red dot shown during active calls, derived from an E-model MOS approximation using jitter and packet loss; hover for MOS score, jitter, and loss values

### Fixed
- BLF presence notifications were silently dropped — Rust callback fired `BlfStatus` but the event router expected `BlfStatusChanged`; renamed to match
- BLF subscriptions now also fire on `PJSIP_EVSUB_STATE_PENDING` so early presence state is captured
- Contact list no longer shows duplicate presence status when server activity note matches the presence state label

---

## 0.4.0

### Fixed
- TLS transport now initialises correctly at startup — accounts configured with TLS no longer silently fall back to UDP
- Webhook and CRM lookup URLs with leading/trailing whitespace no longer cause a `FormatException` on first use
- Recording upload now verifies the file exists before sending and includes richer metadata (`call_id`, `direction`, `duration_seconds`, `started_at`, `ended_at`, `contact_name`, `company`)

### Added
- Structured engine startup log showing transport availability: `Transports: UDP=OK TCP=OK TLS=OK`
- Per-account transport selection logged at registration time (e.g. `using TLS transport` or `falling back to UDP`)
- Registration state changes logged with SIP status code and reason
- Call transfer status logged with code, reason, and final flag
- HTTP request logging across all integration services — URL, status code, response time, and OK/FAIL/ERROR indicators for webhooks, CRM lookup, screen pop, and recording upload
- CRM lookup tab rebuilt with step-by-step how-it-works guide, exact JSON response format, URL placeholder reference, and timeout explanation
- Incoming call banner updates with contact name when a delayed CRM response arrives after the popup is already shown
- Integration settings tabs are now centred (fewer tabs fit without scrolling)

### Removed
- Clipboard monitoring (was triggering unintended popups)
- Dialing rules and caller ID transformation features removed from integration settings
