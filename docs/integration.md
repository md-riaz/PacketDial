# Integration & Automation Guide

PacketDial is built to be "Integration-First." Whether you are a small business owner using Excel or a developer building a custom CRM, PacketDial provides simple ways to automate your calling and react to VoIP events.

## Why Integrate?
- **Speed**: Click a contact in your CRM to dial instantly.
- **Accuracy**: No more manual typing errors when dialing numbers.
- **Workflow**: Auto-populate support tickets when an incoming call starts.
- **Efficiency**: Automate repetitive tasks like checking registration status.

---

## 1. How it Works (Overview)

PacketDial uses a "Controller" model. The main application runs in the background, and a small utility named `pd.exe` sends it commands.

```mermaid
graph LR
    User["User/CRM/Excel"] -- "pd.exe dial 123" --> PD_EXE["pd.exe (Controller)"]
    PD_EXE -- "Named Pipe" --> APP["PacketDial App (Engine)"]
    APP -- "SIP/VoIP" --> Provider["VoIP Provider"]
```

---

## 2. Using the Command Line (`pd.exe`)

The `pd.exe` tool (found in the `bin/` folder) is your primary tool for automation. You can run these commands from a Command Prompt (CMD) or PowerShell.

### Most Common Actions

| Goal | Command | Benefit |
|------|---------|---------|
| **Start a Call** | `pd dial <number>` | Instant click-to-dial. |
| **Answer** | `pd answer` | Remote pick-up via hotkey or script. |
| **Hangup** | `pd hangup` | Quickly end all active calls. |
| **Mute** | `pd mute on` | Privacy during a call. |
| **Events** | `pd events` | Watch live call states (ringing/answered). |

> [!TIP]
> **Smart Account Selection**: If you have multiple accounts, `pd dial` will automatically use the one that is currently registered. You don't need to specify which account to use!

---

## 3. Practical Use Cases

### A. Click-to-Dial from CRM (Web or Desktop)
Most CRM systems allow you to link phone numbers to a command. 
- **Configuration**: Set your CRM to trigger: `path/to/bin/pd.exe dial {phone_number}`
- **Effect**: Clicking a customer's phone number in your browser will trigger PacketDial to call them immediately.

### B. Dialing from an Excel Spreadsheet
You can create a "Dial" button in Excel using a simple macro:
```vba
' Example VBA Macro button
Sub DialNumber()
    Dim phoneNumber As String
    phoneNumber = ActiveCell.Value
    Shell("C:\PacketDial\bin\pd.exe dial " & phoneNumber)
End Sub
```

### C. PowerShell Automation Snippet
Need to dial a list of VIP customers from a text file?
```powershell
# Simple PowerShell script to dial a list
$numbers = Get-Content "customers.txt"
foreach ($n in $numbers) {
    Write-Host "Dialing $n..."
    pd dial $n
    # Wait for the call to finish manually before dialing next or add logic to check status
    Start-Sleep -Seconds 30 
}
```

---

## 4. Web Integration (tel: & sip: links)

PacketDial supports standard click-to-dial functionality via `tel:` and `sip:` links often found on websites or email signatures.

### Setup
Run the registration script as Administrator once to enable this:
```powershell
.\scripts\register_protocols.ps1
```

### Usage
Once registered, clicking any `tel:5550199` link on a website will automatically open PacketDial and start the call.

---

## 5. Deep Dive: Named Pipe API

For developers building sophisticated integrations, PacketDial opens a **Named Pipe** (or Local Socket). This allows high-speed, bidirectional communication between your app and the softphone.

### Connection Details
- **Pipe Name**: `\\.\pipe\PacketDial.API`
- **Protocol**: Line-based JSON (every message must end with `\n`).
- **Mode**: Bidirectional. Your app sends "Commands," and the engine broadcasts "Events."

### Command/Response Model
When you send a command, the engine immediately returns a `CommandResponse`.

**Your Command**:
```json
{ "type": "EnginePing", "payload": {} }
```

**Engine Response**:
```json
{ "type": "CommandResponse", "payload": { "rc": 0 } }
```
- `rc: 0`: Success (Command accepted).
- `rc: 1-6`: Logical Errors (Already initialized, Not found, etc.).
- `rc: 100`: Internal Error.

---

### Commands Reference

| Command Type | Payload Example | Description |
|--------------|-----------------|-------------|
| `CallStart` | `{"uri": "sip:100@dom.com"}` | Initiates an outgoing call. |
| `CallAnswer`| `{"call_id": 1}` | Answers an incoming ringing call. |
| `CallHangup`| `{"call_id": 1}` | Ends the specified call. |
| `CallMute`  | `{"muted": true}` | Mutes/Unmutes the microphone. |
| `CallHold`  | `{"hold": true}` | Places call on hold / resumes. |
| `EnginePing`| `{}` | Check if engine is alive (`EnginePong` follows). |
| `AudioListDevices` | `{}` | Requests the list of audio devices. |

---

### Events Reference
Once connected, your app will automatically receive these events in real-time.

| Event Type | Key Payload Data | When it occurs |
|------------|------------------|----------------|
| `EngineReady`| `{}` | Engine is fully loaded and ready for SIP. |
| `CallStateChanged`| `{"state": "Confirmed"}` | Call status updates (Ringing -> InCall). |
| `MediaStatsUpdated`| `{"jitter_ms": 2.5}` | Real-time quality stats during a call. |
| `EngineLog`| `{"message": "..."}` | Debugging information from the core. |
| `RegistrationStateChanged`| `{"state":"Registered"}` | Account connection status updates. |

---

### Language Examples

#### A. Python (Using `pywin32`)
```python
import win32file
import json

# Connect to the pipe
handle = win32file.CreateFile(
    r"\\.\pipe\PacketDial.API",
    win32file.GENERIC_READ | win32file.GENERIC_WRITE,
    0, None, win32file.OPEN_EXISTING, 0, None
)

# Send a dial command
cmd = {"type": "CallStart", "payload": {"uri": "sip:123@domain.com"}}
win32file.WriteFile(handle, (json.dumps(cmd) + "\n").encode())

# Read response/events
_, data = win32file.ReadFile(handle, 4096)
print(f"Received: {data.decode()}")
```

#### B. C# (.NET)
```csharp
using System.IO.Pipes;

using (var pipe = new NamedPipeClientStream(".", "PacketDial.API", PipeDirection.InOut))
{
    pipe.Connect();
    using (var reader = new StreamReader(pipe))
    using (var writer = new StreamWriter(pipe) { AutoFlush = true })
    {
        // Send command
        writer.WriteLine("{\"type\":\"EnginePing\", \"payload\":{}}");

        // Listen for events in a loop
        while (true) {
            string line = reader.ReadLine();
            Console.WriteLine("Event: " + line);
        }
    }
}
```
