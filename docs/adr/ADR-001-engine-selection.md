# ADR-001: Engine Selection

## Context
Need robust SIP stack.

## Decision
Use PJSIP instead of rewriting SIP.

## Rationale
- Mature
- Battle-tested
- Avoid 2-year rewrite

## Consequences
- FFI complexity
- Need wrapper isolation