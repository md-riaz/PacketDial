# PacketDial Features

Complete feature list for PacketDial v1.0+

---

## 📞 Call Management

### Basic Calling
- ✅ **Outgoing Calls** - Dial SIP URIs or extensions
- ✅ **Incoming Calls** - Popup window with caller ID
- ✅ **Call Hold/Resume** - Put calls on hold
- ✅ **Call Mute/Unmute** - Mute microphone during calls
- ✅ **DTMF Tones** - Send keypad digits during calls
- ✅ **Call Timer** - Display call duration
- ✅ **Call History** - Track all calls with details

### Advanced Calling
- ✅ **Blind Transfer** - Transfer calls immediately
- ✅ **Attended Transfer** - Consult before transferring
- ✅ **3-Way Conference** - Merge two calls into conference
- ✅ **Multi-Account Support** - Multiple SIP accounts simultaneously
- ✅ **Account Selection** - Choose account per outgoing call

---

## 👥 Contacts & Presence

### BLF (Busy Lamp Field)
- ✅ **Contact List** - File-based BLF contacts
- ✅ **Presence Indicators** - Real-time status (Available/Busy/Ringing)
- ✅ **Status Filtering** - Filter contacts by presence state
- ✅ **Quick Dial** - Call contacts with one click
- ✅ **Contact Search** - Search by name, URI, or extension
- ✅ **Import/Export** - Backup contacts to JSON file

### Contact States
- 🟢 **Available** - Ready to receive calls
- 🔴 **Busy** - Currently on a call
- 🟡 **Ringing** - Incoming call
- ⚪ **Unknown** - Status unavailable

---

## ⚙️ Settings & Configuration

### App-Wide Settings (Settings Tab)

#### General
- ✅ **BLF Toggle** - Enable/disable presence monitoring
- ✅ **Export Settings** - Backup configuration
- ✅ **Import Settings** - Restore configuration
- ✅ **Reset to Defaults** - Factory reset
- ✅ **Diagnostics Access** - View logs and debug info

#### Codecs
- ✅ **Codec Priority** - Drag-to-reorder codec preference
- ✅ **Enable/Disable Codecs** - Toggle individual codecs
- ✅ **Supported Codecs**:
  - G.711 μ-law (PCMU)
  - G.711 A-law (PCMA)
  - G.729
  - G.722 (HD)
  - Opus (HD)
  - GSM
  - iLBC

#### Calls
- ✅ **Do Not Disturb (DND)** - Auto-reject all incoming calls
  - Footer toggle for quick access
  - Red indicator when active
- ✅ **Auto Answer** - Automatically answer incoming calls
- ✅ **DTMF Method** - Choose transmission method
  - In-band Audio
  - RFC2833 (Recommended)
  - SIP INFO

#### Contacts
- ✅ **Contact Statistics** - View presence breakdown
- ✅ **Contact Management** - Link to full contacts page
- ✅ **Import/Export** - Backup contact list

### Per-Account Settings

#### Account Configuration
- ✅ **SIP Credentials** - Username, password, domain
- ✅ **Proxy Settings** - SIP proxy configuration
- ✅ **Transport** - UDP, TCP, or TLS
- ✅ **STUN/TURN** - NAT traversal settings
- ✅ **Registration** - Auto-register on startup

#### Account Features
- ✅ **Call Forwarding** - Forward calls to another number
  - Unconditional (all calls)
  - On Busy
  - On No Answer
- ✅ **Caller Lookup URL** - Custom URL for caller identification
  - Template with `{number}` variable
  - Opens in browser on incoming call
- ✅ **DND Per Account** - Override global DND

---

## 🎨 User Interface

### Main Navigation (5 Tabs)
1. **Dialer** - Keypad, call controls, active call display
2. **Contacts** - BLF contact list with presence
3. **History** - Call history with filtering
4. **Accounts** - SIP account management
5. **Settings** - Unified app settings

### Call Controls
- **MUTE** - Toggle microphone
- **HOLD** - Hold/resume call
- **KEYPAD** - DTMF dialpad
- **TRANSFER** - Blind or attended transfer
- **CONFERENCE** - Add participant / merge calls

### Status Bar (Footer)
- Registration status per account
- Network status
- **DND Toggle** - Quick enable/disable
- App version

### Incoming Call Popup
- Caller name and number
- Account badge (which line is ringing)
- **Lookup Caller** button (if URL configured)
- Answer/Reject buttons
- Always-on-top window

---

## 🔧 Technical Features

### Backend Architecture
- ✅ **PJSIP 2.14.1** - Battle-tested SIP stack
- ✅ **Rust Core** - Memory-safe FFI layer
- ✅ **Flutter Desktop** - Modern cross-platform UI
- ✅ **Direct C ABI** - High-performance communication

### File-Based Persistence
- ✅ **App Settings** - `%APPDATA%\PacketDial\app_settings.json`
- ✅ **Contacts** - `%APPDATA%\PacketDial\blf_contacts.json`
- ✅ **No Database** - Simple JSON files, easy to backup

### Security
- ✅ **TLS Support** - Encrypted SIP signaling (config flag)
- ✅ **SRTP Support** - Encrypted media (config flag)
- ✅ **Password Storage** - In-memory (Credential Manager planned)

### Audio
- ✅ **Audio Device Selection** - Choose mic/speaker
- ✅ **Wideband Audio** - 16kHz sampling
- ✅ **Echo Cancellation** - 200ms tail
- ✅ **DTMF Playback** - Local feedback

---

## 📦 Distribution

### Packaging Options

#### Windows Installer
- ✅ **Inno Setup** - Professional installer
- ✅ **Silent Install** - `/VERYSILENT` switch
- ✅ **Start Menu** - Automatic shortcuts
- ✅ **Desktop Icon** - Optional
- ✅ **Uninstaller** - Control Panel integration

#### Portable Version
- ✅ **No Installation** - Extract and run
- ✅ **USB Compatible** - Run from removable drive
- ✅ **Uninstaller Script** - `UNINSTALL.bat`
- ✅ **Shortcut Creator** - `CreateShortcut.bat`

### Build System
- ✅ **Automated Build** - `build_all.ps1`
- ✅ **Version Management** - Semantic versioning
- ✅ **CI/CD Ready** - GitHub Actions workflows
- ✅ **Code Signing Ready** - Authenticode support

---

## 🚀 Planned Features (Roadmap)

### Short Term (v1.1)
- ⏳ **Windows Credential Manager** - Secure password storage
- ⏳ **Audio Device Hot-Swap** - Runtime device refresh
- ⏳ **Multiple Active Calls** - Full call management UI
- ⏳ **Call Recording** - Record calls to file

### Medium Term (v1.2)
- 🔜 **Video Calls** - SIP video support
- 🔜 **Instant Messaging** - SIP SIMPLE
- 🔜 **File Transfer** - MSRP support
- 🔜 **Conference Bridge** - 5+ party conferences

### Long Term (v2.0)
- 📅 **Linux Support** - GTK or Qt backend
- 📅 **macOS Support** - Native desktop app
- 📅 **Mobile Apps** - iOS/Android Flutter apps
- 📅 **Cloud Sync** - Settings backup to cloud

---

## 📊 Feature Comparison

| Feature | PacketDial | MicroSIP | Zoiper |
|---------|------------|----------|--------|
| Multi-Account | ✅ | ✅ | ✅ |
| BLF/Presence | ✅ | ❌ | ⚠️ |
| Call Transfer | ✅ | ✅ | ✅ |
| Conference | ✅ (3-way) | ❌ | ✅ |
| Settings UI | ✅ | ⚠️ | ✅ |
| Portable | ✅ | ✅ | ❌ |
| Installer | ✅ | ✅ | ✅ |
| Open Source | ✅ | ✅ | ❌ |
| Rust Backend | ✅ | ❌ | ❌ |

✅ = Fully implemented  
⚠️ = Limited implementation  
❌ = Not available

---

## 🎯 Use Cases

### Business Users
- Multi-account support for different lines
- BLF for colleague presence
- Call transfer for receptionists
- Conference for team calls

### Call Centers
- BLF for agent availability
- Call forwarding for overflow
- DND for break times
- Call history for tracking

### Remote Workers
- Portable version for travel
- Multiple account support
- Easy setup with installer
- Simple backup via JSON files

### Developers
- Open source for customization
- Rust FFI for integrations
- Event broadcasting API
- CLI control interface

---

**PacketDial v1.0** - Modern Windows SIP Client  
Last updated: March 2026
