# Integration & Automation Guide

PacketDial is designed to be "Integration-First," allowing businesses to control the softphone and react to VoIP events from external applications, CRMs, or scripts.

## 1. CLI Controller (`pd.exe`)

The `pd.exe` utility (located in the `bin/` directory) is the primary way to automate PacketDial actions.

### Basic Commands

| Command | Description | Example |
|---------|-------------|---------|
| `pd dial <uri>` | Starts an outgoing call. | `pd dial sip:100@domain.com` |
| `pd answer` | Answers the first ringing incoming call. | `pd answer` |
| `pd hangup` | Terminates all active calls. | `pd hangup` |
| `pd mute <on/off>`| Mutes or unmutes the local microphone. | `pd mute on` |
| `pd hold <on/off>`| Places the active call on hold or resumes. | `pd hold on` |
| `pd events` | Streams all engine events to `stdout`. | `pd events` |

### Automation Tip
The `dial` command is intelligent: if no account is specified, it will automatically use the first successfully registered account it finds.

---

## 2. IPC API (Named Pipes)

For deep integration, your application can connect directly to the PacketDial API server via a Windows Named Pipe.

**Pipe Name:** `\\.\pipe\PacketDial.API`

### JSON Protocol
Communication is line-based JSON. Every message from the client must end with a newline `\n`.

#### Sending a Command
```json
{
  "type": "CallStart",
  "payload": {
    "uri": "sip:100@domain.com",
    "account_id": "optional-uuid"
  }
}
```

#### Receiving a Response
The engine responds to every command with a return code (`rc`).
```json
{
  "type": "CommandResponse",
  "payload": {
    "rc": 0
  }
}
```

### Event Broadcasting
When you connect to the pipe, you automatically start receiving a stream of events. Multiple clients can connect simultaneously.

**Example Event (Call State):**
```json
{
  "type": "CallStateChanged",
  "payload": {
    "call_id": 1,
    "state": "Confirmed",
    "remote_uri": "sip:100@domain"
  }
}
```

---

## 3. Protocol Handler Integration

PacketDial supports standard click-to-dial functionality via `tel:` and `sip:` URI schemes.

### Registration
To register PacketDial as the system handler, run the following script with Administrator privileges:
```powershell
.\scripts\register_protocols.ps1
```

### How it Works
When a user clicks a `tel:12345` link:
1. Windows executes `pd.exe dial "tel:12345"`.
2. `pd.exe` connects to the running PacketDial engine via the Named Pipe.
3. The engine initiates the call immediately.
4. If PacketDial is not running, the `pd.exe` tool will report an error.

## 4. Building from Source

If you are a developer and want to modify the CLI or DLL:
- **Rust Core:** `cd core_rust; cargo build`
- **CLI Tool:** `cd tools/pd; cargo build`

The resulting binaries will be in their respective `target/debug` or `target/release` folders.
