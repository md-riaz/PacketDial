# Product Specification (Production Grade)

## 1. Vision

Create a modern, open-source, developer-grade Windows SIP softphone that:
- Is stable under complex NAT conditions
- Exposes deep SIP diagnostics
- Maintains strict security practices
- Is maintainable for 5+ years

---

## 2. Target Personas

### 2.1 VoIP Engineer
Needs deep SIP trace, RTP metrics, ICE visibility.

### 2.2 SMB User
Needs stable calling and easy configuration.

### 2.3 QA Engineer
Needs reproducible diagnostics and export bundles.

---

## 3. Functional Requirements

### 3.1 Account Management
- Multi-account support
- UDP, TCP (TLS in v1.1)
- STUN, TURN, ICE toggle
- Secure credential storage

### 3.2 Registration
States:
Unregistered → Registering → Registered → Failed

Must:
- Handle 401 challenges
- Retry with backoff
- Detect network loss

### 3.3 Calling
- Outgoing call
- Incoming call
- Hold / Resume
- Mute
- Device switching during call

### 3.4 Media
- RTP / SRTP
- Codec negotiation
- Jitter reporting
- Packet loss calculation

### 3.5 Diagnostics
- SIP trace viewer (raw + parsed)
- ICE candidate list
- Media stats panel
- Export bundle (masked)

---

## 4. Non-Functional Requirements

- Startup < 2 seconds
- Idle RAM target < 150MB
- Crash-free rate > 99%
- Log masking mandatory
- Deterministic builds

---

## 5. Milestones

M0 – Build System  
M1 – Registration  
M2 – Calling  
M3 – Diagnostics  
M4 – Packaging  
M5 – Hardening & TLS  

Each milestone must include:
- Tests
- Updated documentation
- Manual QA checklist
- CI pass