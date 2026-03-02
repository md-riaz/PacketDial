# Architecture Document

## 1. System Overview

UI (Flutter Desktop)
  ↕ Commands/Events
Core (Rust Wrapper)
  ↕ FFI
PJSIP Engine (C)

---

## 2. Core Responsibilities (Rust)

- State machines
- Thread isolation
- Event bus
- Secure storage orchestration
- Diagnostics aggregation

---

## 3. Threading Model

- Dedicated engine thread for all PJSIP operations
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

Events serialized as JSON (v1), future protobuf support.

---

## 5. Failure Isolation

- Panic recovery in Rust core
- Graceful engine shutdown
- Watchdog restart (future milestone)

---

## 6. Scalability Considerations

Though single-user app, architecture supports:
- Plugin system
- Future macOS/Linux port
- Headless CLI mode