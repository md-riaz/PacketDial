# Security Model

## 1. Threat Model

Potential risks:
- Credential leakage
- SIP auth replay exposure
- Log file exfiltration
- Malicious SIP server behavior

---

## 2. Secret Handling

- Windows Credential Manager for passwords
- Never stored in config files
- Mask Authorization headers in logs

---

## 3. Log Sanitization Rules

Mask:
- Authorization
- Proxy-Authorization
- TURN credentials
- SIP URIs with passwords

---

## 4. Diagnostics Export

Options:
- anonymize=true
- include_body=false (default)

---

## 5. Future Enhancements

- TLS transport
- SRTP enforcement toggle
- Certificate validation policies