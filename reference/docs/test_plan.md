# Test Plan

## 1. Unit Tests (Rust)

- Registration state transitions
- Call state transitions
- Log masking verification
- Error handling tests

---

## 2. Integration Tests

- Init/shutdown stress test (100 loops)
- Register to test server
- Simulate network drop

---

## 3. Manual QA Checklist

Registration:
- Success
- Wrong password
- Network unavailable

Calling:
- Outgoing
- Incoming
- Hold/Resume
- Device switch

Diagnostics:
- SIP trace visible
- Media stats updating
- Export bundle generated

---

## 4. Regression Strategy

- Maintain bug reproduction cases
- Add failing test before fixing bug