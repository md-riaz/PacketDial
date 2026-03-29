# API Contract (UI ↔ Rust Core)

## Versioning

Current API Version: 0.1.0

---

## Command Schema

All commands include:
{
  "type": "CommandName",
  "payload": {}
}

Examples:

EngineInit
AccountUpsert
AccountRegister
CallStart
CallAnswer
CallHangup
AudioSetDevices
DiagExportBundle

---

## Event Schema

All events include:
{
  "type": "EventName",
  "payload": {}
}

Examples:

EngineReady
RegistrationStateChanged
CallCreated
CallStateChanged
MediaStatsUpdated
SipMessageCaptured

---

## Error Handling

Errors returned as structured events:
EngineError { code, message }

No panics exposed to UI.