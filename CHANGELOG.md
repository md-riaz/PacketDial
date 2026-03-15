# Changelog

## Unreleased

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
