# Architecture Document

## 1. System Overview

UI (Flutter Desktop)  <-- FFI callback
  ↕
Core (Rust Wrapper)  <-- IPC API Server (\\\\.\\pipe\\PacketDial.API)
  ↕                       ↕
PJSIP Engine (C)      External Controllers (pd.exe, CRM, etc.)

---

## 2. Core Responsibilities (Rust)

- State machines
- Thread isolation
- **IPC API Server**: Manages Named Pipe connections and JSON command dispatch.
- **Event Broadcasting**: Fans out VoIP events to all connected IPC subscribers.
- Event bus
- Secure storage orchestration
- Diagnostics aggregation

---

## 3. Threading Model

- Dedicated engine thread for all PJSIP operations
- **IPC Worker Threads**: Each connected pipe client gets a dedicated worker for handling bidirectional I/O without blocking the engine.
- Event queue for UI communication
- No direct UI-PJSIP calls

Rationale:
Prevents race conditions and undefined behavior.

---

## 4. Event Bus Design

All updates are structured events:
- RegistrationStateChanged
- CallStateChanged
- MediaStatsUpdated
- SipMessageCaptured

The Rust core operates a **multi-subscriber broadcast** system:
1. Event is generated (e.g., from PJSIP callback).
2. Event is pushed to the UI via the FFI callback.
3. Event is simultaneously broadcast to all active IPC clients via Named Pipes.

---

## 5. Failure Isolation

- Panic recovery in Rust core
- Graceful engine shutdown
- Watchdog restart (future milestone)

---

## 6. Scalability Considerations

Architecture supports:
- Plugin system
- **Programmability**: External tools can control the phone via IPC.
- Headless CLI mode