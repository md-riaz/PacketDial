# Multi-Window Removal Plan

## Executive Summary

This plan outlines the complete removal of the multi-window functionality from PacketDial and replacing it with single-window, dedicated inner-page dialogs. The app is small enough that all form-based windows should be dedicated inner pages with minimal padding for maximum form control space.

---

## Current Multi-Window Usage

### 1. **Incoming Call Popup** (`incoming_call_popup.dart`)
- **Location**: `app_flutter/lib/screens/incoming_call_popup.dart`
- **Purpose**: Shows incoming call notification with answer/reject buttons
- **Launch Trigger**: `IncomingCallController` listens to `EngineChannel` events
- **Window Type**: `WindowType.incomingCall`
- **Features**:
  - Pulsing call indicator
  - Caller ID display (name, number, domain)
  - Customer data integration (CRM lookup)
  - Answer/Reject actions via IPC
  - "Open CRM Record" button

### 2. **Account Setup Window** (`account_setup_window.dart`)
- **Location**: `app_flutter/lib/screens/account_setup_window.dart`
- **Purpose**: Add/Edit SIP account configuration form
- **Launch Trigger**: `AccountSetupWindowController` from Accounts screen
- **Window Type**: `WindowType.accountSetup`
- **Features**:
  - Full SIP account configuration form
  - Registration testing before save
  - Advanced settings expansion panel
  - Form validation

### 3. **Multi-Window Infrastructure**
- **Router**: `app_flutter/lib/core/multi_window/window_router.dart`
- **Window Type Enum**: `app_flutter/lib/core/multi_window/window_type.dart`
- **Controllers**:
  - `incoming_call_controller.dart` - Manages incoming call popup
  - `account_setup_window_controller.dart` - Manages account setup window
- **Extension**: `window_controller_extension.dart` - Window method handlers
- **Dependency**: `desktop_multi_window: ^0.3.0` in `pubspec.yaml`

### 3. **Multi-Window Infrastructure**
- **Router**: `app_flutter/lib/core/multi_window/window_router.dart`
- **Window Type Enum**: `app_flutter/lib/core/multi_window/window_type.dart`
- **Controllers**:
  - `incoming_call_controller.dart` - Manages incoming call popup
  - `account_setup_window_controller.dart` - Manages account setup window
- **Extension**: `window_controller_extension.dart` - Window method handlers
- **Dependency**: `desktop_multi_window: ^0.3.0` in `pubspec.yaml`

---

## Removal Strategy

### Phase 1: Replace Account Setup Window with Inner Page

**File**: `app_flutter/lib/screens/account_setup_window.dart`

**Changes**:
1. Convert `AccountSetupWindow` widget to `AccountSetupPage`
2. Remove `WindowController` dependency
3. Remove `bitsdojo_window` and `window_manager` calls
4. Convert to standard Flutter page with `Scaffold`
5. Replace IPC communication with direct callback functions
6. Remove all `invokeMethod` calls (`tryRegister`, `saveAccount`, `close`, `setContent`, `windowReady`)
7. Replace with direct service calls via `AccountService`
8. Add back button in top-left corner using `AppBar.leading`
9. **Remove auto-register checkbox** (moved to Accounts page toggle)

**Implementation**:
```dart
// OLD: Window-based
await widget.windowController.invokeMethod('tryRegister', jsonEncode(args));

// NEW: Direct service call
final result = await ref.read(accountServiceProvider).tryRegister(...);
```

**Navigation**:
```dart
// From AccountsScreen
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (_) => AccountSetupPage(existing: existing),
  ),
);

// After save, pop back
Navigator.of(context).pop(true);
```

**Page Specifications**:
- Use `Scaffold` with custom `AppBar`
- `AppBar.leading`: Back button (arrow left)
- `AppBar.title`: "Add SIP Account" or "Edit Account"
- Minimal padding: `EdgeInsets.all(16)` for maximum form space
- Full window width/height (no inset constraints)
- Fixed bottom action bar with `Cancel` and `Save Account` buttons
- `SingleChildScrollView` for content overflow
- **No auto-register checkbox** (account is registered on save, toggled from Accounts page)

---

### Phase 2: Replace Incoming Call Popup with Overlay/Banner

**File**: `app_flutter/lib/screens/incoming_call_popup.dart`

**Changes**:
1. Convert `IncomingCallPopup` widget to `IncomingCallBanner`
2. Remove `WindowController` dependency
3. Remove `desktop_multi_window` imports
4. Implement as overlay banner in main window (not modal dialog)
5. Use `Stack` + `Positioned` in main app shell
6. Replace IPC with direct `EngineChannel` calls
7. Keep always-on-top behavior via window manager

**Implementation Options**:

**Option A - Overlay Banner (Recommended)**:
- Add to `_buildMainShell()` in `main.dart`
- Positioned at top of screen
- Slides down on incoming call
- Non-blocking but prominent
- Auto-dismisses on answer/reject

**Option B - Modal Dialog**:
- Use `showDialog` with `barrierDismissible: false`
- Always-on-top via `windowManager.setAlwaysOnTop(true)`
- More intrusive but clearer UX

**Recommended**: Option A (Overlay Banner)
- Better UX for softphone app
- User can see main window while call rings
- Consistent with modern softphone design

---

### Phase 3: Remove Multi-Window Infrastructure

**Files to Delete**:
1. `app_flutter/lib/core/multi_window/window_router.dart`
2. `app_flutter/lib/core/multi_window/window_type.dart`
3. `app_flutter/lib/core/multi_window/window_controller_extension.dart`
4. `app_flutter/lib/core/multi_window/controllers/incoming_call_controller.dart`
5. `app_flutter/lib/core/multi_window/controllers/account_setup_window_controller.dart`
6. Entire directory: `app_flutter/lib/core/multi_window/`

**Changes to `main.dart`**:
1. Remove multi-window routing logic (lines 56-72 approx)
2. Remove imports:
   - `package:desktop_multi_window/desktop_multi_window.dart`
   - `core/multi_window/controllers/incoming_call_controller.dart`
   - `core/multi_window/window_router.dart`
   - `core/multi_window/window_type.dart`
3. Remove `WindowRouter.getAppForArgs` check
4. Remove sub-window initialization code
5. Integrate `IncomingCallBanner` into main widget tree

---

### Phase 4: Update Dependencies

**File**: `app_flutter/pubspec.yaml`

**Remove**:
```yaml
desktop_multi_window: ^0.3.0
```

**Keep** (still needed):
```yaml
window_manager: ^0.5.1
bitsdojo_window: ^0.1.6
```

---

### Phase 7: Increase App Window Size

**File**: `app_flutter/lib/main.dart`

**Changes**:
Increase the default window size for better usability and form space.

**Current Size**:
```dart
WindowOptions windowOptions = const WindowOptions(
  size: Size(360, 760),
  // ...
);

appWindow.minSize = const Size(320, 700);
appWindow.size = initialSize; // 360x760
```

**New Size**:
```dart
WindowOptions windowOptions = const WindowOptions(
  size: Size(450, 850),  // Increased from 360x760
  // ...
);

appWindow.minSize = const Size(400, 750);  // Increased from 320x700
appWindow.size = initialSize; // 450x850
```

**Benefits**:
- More horizontal space for forms (Account Setup page)
- Better readability for account cards
- More comfortable for users (less cramped UI)
- Still compact enough for a softphone app

---

### Phase 8: Add Long-Press Menu and Switch Toggle to Account Cards

**File**: `app_flutter/lib/screens/accounts_screen.dart`

**Changes**:
Replace inline action buttons with:
1. **Switch toggle** for register/unregister (visible on card)
2. **Long-press menu** for additional actions (Edit, Delete)
3. **Tap card** to navigate to Edit page

**Current Layout**:
```
┌─────────────────────────────────────┐
│ 📞 Work Account                     │
│    john@sip.provider.com            │
│    [Active] [Edit] [Delete]         │ ← Inline buttons
└─────────────────────────────────────┘
```

**New Layout**:
```
┌─────────────────────────────────────┐
│ 📞 Work Account              [✓]    │ ← Switch toggle
│    john@sip.provider.com            │
│    Registered                       │ ← Status text
└─────────────────────────────────────┘
```

**Interactions**:
- **Tap card**: Navigate to Account Setup Page (edit mode)
- **Toggle switch**: Register/Unregister account
- **Long-press card**: Show context menu (Edit, Delete)

**Switch Toggle Behavior**:
- **ON (green)**: Account is registered/active
- **OFF (gray)**: Account is unregistered/inactive
- Toggling ON registers the account (and unregisters previously active one)
- Toggling OFF unregisters the account

**Long-Press Menu Items**:
- Edit (pencil icon) - Opens Account Setup Page
- Delete (trash icon, red) - Deletes account

**Implementation**:
```dart
class _AccountCard extends ConsumerStatefulWidget {
  // ...
}

class _AccountCardState extends ConsumerState<_AccountCard> {
  bool _isRegistering = false;

  void _showActionsMenu() {
    final renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.right - 40,
        offset.top + 10,
        offset.right,
        offset.bottom,
      ),
      items: [
        const PopupMenuItem(
          value: 'edit',
          icon: Icon(Icons.edit, size: 20),
          child: Text('Edit'),
        ),
        const PopupMenuItem(
          value: 'delete',
          icon: Icon(Icons.delete, size: 20),
          child: Text('Delete', style: TextStyle(color: Colors.red)),
        ),
      ],
    ).then((value) {
      if (value == 'edit') {
        parent._showAccountSetup(widget.account);
      } else if (value == 'delete') {
        _deleteAccount();
      }
    });
  }

  Future<void> _toggleRegistration(bool? value) async {
    if (_isRegistering) return;
    setState(() => _isRegistering = true);
    
    try {
      final service = ref.read(accountServiceProvider);
      if (value == true) {
        // Register this account
        await service.setSelectedAccount(widget.account.uuid);
      } else {
        // Unregister - set no active account
        await service.setSelectedAccount('');
      }
      ref.invalidate(accountsListProvider);
    } finally {
      setState(() => _isRegistering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => parent._showAccountSetup(widget.account),
      onLongPress: _showActionsMenu,
      child: Container(
        // ... card decoration
        child: Row(
          children: [
            // Avatar
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  widget.account.accountName[0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Account info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.account.accountName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: widget.account.isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${widget.account.username}@${widget.account.server}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            // Switch toggle
            Transform.scale(
              scale: 0.8,
              child: Switch(
                value: widget.account.isSelected,
                onChanged: _isRegistering ? null : _toggleRegistration,
                activeColor: AppTheme.callGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

**Benefits**:
- Clear visual toggle for registration state
- Intuitive switch control (ON/OFF)
- Tap to edit (common pattern)
- Long-press for secondary actions (modern mobile pattern)
- Cleaner card design
- No hidden menus for primary action (register/unregister)

---

### Phase 9: Update Platform-Specific Code

**Windows**:
- `app_flutter/windows/runner/flutter_window.cpp`
  - Remove `DesktopMultiWindowSetWindowCreatedCallback`
- `app_flutter/windows/flutter/generated_plugin_registrant.cc`
  - Remove `DesktopMultiWindowPlugin` registration
- `app_flutter/windows/flutter/generated_plugins.cmake`
  - Remove `desktop_multi_window` reference

**Linux**:
- `app_flutter/linux/flutter/generated_plugin_registrant.cc`
  - Remove `desktop_multi_window_plugin_register_with_registrar`
- `app_flutter/linux/flutter/generated_plugins.cmake`
  - Remove `desktop_multi_window` reference

---

### Phase 6: Update Callers

**File**: `app_flutter/lib/screens/accounts_screen.dart`

**Changes**:
```dart
// OLD
ref.read(accountSetupWindowControllerProvider).showWindow(existing);

// NEW
void _showAccountSetup([AccountSchema? existing]) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => AccountSetupPage(existing: existing),
    ),
  ).then((saved) {
    if (saved == true) {
      // Refresh account list
      ref.invalidate(accountsListProvider);
    }
  });
}
```

**File**: `app_flutter/lib/main.dart`

**Changes**:
1. Remove `IncomingCallController.instance.init()`
2. Add `IncomingCallBanner` to widget tree
3. Remove window close confirmation dialog (keep as-is, it's already a dialog)

---

## New Component Specifications

### AccountSetupPage

```dart
class AccountSetupPage extends StatefulWidget {
  final AccountSchema? existing;
  
  const AccountSetupPage({
    Key? key,
    this.existing,
  });
}
```

**Layout**:
```
┌─────────────────────────────────────────┐
│  ← Add/Edit SIP Account                │ ← AppBar with back button
├─────────────────────────────────────────┤
│                                         │
│  Identity Section                       │
│  ┌───────────────────────────────────┐  │
│  │ Account Label                     │  │
│  │ Display Name                      │  │
│  └───────────────────────────────────┘  │
│                                         │
│  Server Section                         │
│  ┌───────────────────────────────────┐  │
│  │ SIP Server                        │  │
│  │ Username                          │  │
│  │ Password                          │  │
│  └───────────────────────────────────┘  │
│                                         │
│  ▼ Advanced Settings                    │
│  ┌───────────────────────────────────┐  │
│  │ Auth Username                     │  │
│  │ Domain                            │  │
│  │ Transport (dropdown)              │  │
│  │ STUN Server                       │  │
│  │ TURN Server                       │  │
│  └───────────────────────────────────┘  │
│                                         │
├─────────────────────────────────────────┤
│                    [Cancel] [Save]      │ ← Fixed bottom
└─────────────────────────────────────────┘
```

**Removed**:
- ~~Auto-register checkbox~~ → Moved to Accounts page as account toggle

**AppBar**:
- `leading`: `BackButton()` (arrow left icon)
- `title`: Text("Add SIP Account") or Text("Edit Account")
- `backgroundColor`: AppTheme.surfaceVariant
- `elevation`: 0 or minimal

**Padding**: `EdgeInsets.all(16)` (minimal for maximum form space)

**Navigation**:
- Push: `Navigator.push(context, MaterialPageRoute(...))`
- Pop on save: `Navigator.pop(context, true)`
- Pop on cancel: `Navigator.pop(context, false)`

---

### Accounts Page - Switch Toggle & Long-Press Menu

Add switch toggle for registration and long-press context menu to account cards.

**Layout**:
```
┌─────────────────────────────────────────┐
│  Accounts                        [+]    │
├─────────────────────────────────────────┤
│                                         │
│  ┌─────────────────────────────────┐   │
│  │ 📞 Work Account       [Switch]  │   │ ← Toggle register
│  │    john@sip.provider.com        │   │
│  └─────────────────────────────────┘   │
│  (Tap to edit, Long-press for menu)     │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │ 📞 Personal           [Switch]  │   │
│  │    bob@voip.example.com         │   │
│  └─────────────────────────────────┘   │
│  (Tap to edit, Long-press for menu)     │
│                                         │
└─────────────────────────────────────────┘
```

**Interactions**:
| Action | Result |
|--------|--------|
| **Tap card** | Open Account Setup Page (edit mode) |
| **Toggle switch** | Register/Unregister account |
| **Long-press card** | Show context menu (Edit, Delete) |

**Switch Behavior**:
- **ON (green)**: Account is registered/active with SIP
- **OFF (gray)**: Account is unregistered/inactive
- Toggling ON → Registers account, unregisters previous active
- Toggling OFF → Unregisters account (no active account)
- Shows loading state during registration process

**Context Menu** (Long-press):
- **Edit** (pencil icon) → Opens Account Setup Page
- **Delete** (trash icon, red) → Deletes account with confirmation

---

### IncomingCallBanner

```dart
class IncomingCallBanner extends StatefulWidget {
  final Map<String, dynamic> callInfo;
  final VoidCallback onAnswer;
  final VoidCallback onReject;
  
  const IncomingCallBanner({
    Key? key,
    required this.callInfo,
    required this.onAnswer,
    required this.onReject,
  });
}
```

**Layout**:
```
┌─────────────────────────────────────────┐
│  PacketDial                      [_][□][X]
├─────────────────────────────────────────┤
│ ╔═══════════════════════════════════╗   │
│ ║  📞 INCOMING CALL                 ║   │
│ ║                                   ║   │
│ ║      (John Doe)                   ║   │
│ ║      John Doe                     ║   │
│ ║      Acme Corp                    ║   │
│ ║      +1-555-1234                  ║   │
│ ║                                   ║   │
│ ║      📞 SIP Account: Work         ║   │
│ ║                                   ║   │
│ ║      [🔗 Open CRM]                ║   │
│ ║                                   ║   │
│ ║      [Reject]     [Answer]        ║   │
│ ╚═══════════════════════════════════╝   │
│                                         │
│  [Dialer] [Contacts] [History] [...]    │
└─────────────────────────────────────────┘
```

**Position**: Centered at top, overlaying content
**Animation**: Slide down on appear, fade out on dismiss
**Z-index**: Above all content, below title bar

---

## File-by-File Changes Summary

### Files to Modify

| File | Changes |
|------|---------|
| `lib/main.dart` | Remove multi-window routing, add banner widget, remove controller init, increase window size |
| `lib/screens/accounts_screen.dart` | Replace controller call with Navigator.push, add switch toggle + long-press menu |
| `lib/screens/account_setup_window.dart` | Convert to inner page with back button, remove IPC |
| `lib/screens/incoming_call_popup.dart` | Convert to banner overlay, remove IPC |
| `pubspec.yaml` | Remove `desktop_multi_window` dependency |

### Files to Delete

| File | Reason |
|------|--------|
| `lib/core/multi_window/window_router.dart` | No longer needed |
| `lib/core/multi_window/window_type.dart` | No longer needed |
| `lib/core/multi_window/window_controller_extension.dart` | No longer needed |
| `lib/core/multi_window/controllers/incoming_call_controller.dart` | Replaced by banner |
| `lib/core/multi_window/controllers/account_setup_window_controller.dart` | Replaced by dialog |

### Platform Files to Modify

| File | Changes |
|------|--------|
| `windows/runner/flutter_window.cpp` | Remove multi-window callback |
| `windows/flutter/generated_plugin_registrant.cc` | Remove plugin registration |
| `windows/flutter/generated_plugins.cmake` | Remove plugin reference |
| `linux/flutter/generated_plugin_registrant.cc` | Remove plugin registration |
| `linux/flutter/generated_plugins.cmake` | Remove plugin reference |

---

## Testing Checklist

### Account Setup Page
- [ ] Navigate to page from Accounts screen (+) button
- [ ] Navigate to page from account card edit button
- [ ] Back button returns to Accounts screen
- [ ] Fill form and save new account
- [ ] Edit existing account and save
- [ ] Test registration validation
- [ ] Test form validation (empty fields)
- [ ] Test advanced settings expansion
- [ ] Test cancel button
- [ ] Account list refreshes after save
- [ ] Test keyboard navigation
- [ ] Test responsive sizing on different window sizes
- [ ] Test page transition animation
- [ ] Verify auto-register checkbox is NOT present

### Accounts Page - Switch Toggle & Long-Press Menu
- [ ] Switch toggle visible on each account card
- [ ] Switch ON = account registered (green)
- [ ] Switch OFF = account unregistered (gray)
- [ ] Toggling ON registers the account
- [ ] Toggling OFF unregisters the account
- [ ] Only one account can be registered at a time
- [ ] Tap card navigates to Account Setup Page (edit)
- [ ] Long-press opens context menu
- [ ] Context menu shows Edit option
- [ ] Context menu shows Delete option (red)
- [ ] Edit from menu opens Account Setup Page
- [ ] Delete from menu removes account
- [ ] Switch shows loading state during registration
- [ ] Account registration persists after app restart

### Incoming Call Banner
- [ ] Banner appears on incoming call
- [ ] Caller ID displays correctly
- [ ] Customer data shows (if available)
- [ ] Answer button works
- [ ] Reject button works
- [ ] CRM link button works (if available)
- [ ] Banner dismisses after answer/reject
- [ ] Banner doesn't appear in DND mode
- [ ] Multiple calls don't create multiple banners
- [ ] Banner animation is smooth
- [ ] Banner doesn't block main window interaction

### App Window Size
- [ ] Window opens at 450x850 size
- [ ] Minimum window size is 400x750
- [ ] Account Setup page has enough horizontal space
- [ ] All forms are properly laid out at new size
- [ ] Window geometry saves/restores correctly

### Accounts Page - 3-Dot Dropdown Menu
- [ ] 3-dot menu button visible on each account card
- [ ] Menu opens on click
- [ ] Active account shows: Edit, Delete, Deactivate
- [ ] Inactive account shows: Activate, Edit, Delete
- [ ] Activate action registers account
- [ ] Deactivate action unregisters account
- [ ] Edit action opens Account Setup page
- [ ] Delete action removes account
- [ ] Menu closes after action selection
- [ ] Menu positioning is correct (aligned to button)

### General
- [ ] App builds without errors
- [ ] No runtime errors related to removed code
- [ ] Window close behavior unchanged
- [ ] Registration failure dialog still works
- [ ] All other dialogs still work (transfer, account select, etc.)

---

## Migration Order

1. **Create new dialog components** (non-breaking)
   - Create `AccountSetupDialog` alongside existing window
   - Create `IncomingCallBanner` alongside existing popup

2. **Update callers** (breaking, but reversible)
   - Update `accounts_screen.dart` to use dialog
   - Update `main.dart` to use banner

3. **Remove old code** (breaking)
   - Delete multi-window controller files
   - Delete window router files
   - Remove dependency from pubspec.yaml

4. **Clean up platform code** (breaking)
   - Update Windows plugin registration
   - Update Linux plugin registration

5. **Test thoroughly**
   - Run all tests from checklist
   - Test on both Windows and Linux

---

## Benefits

### User Experience
- ✅ Faster window transitions (no IPC overhead)
- ✅ Consistent UI/UX across all dialogs
- ✅ Better form space utilization (minimal padding)
- ✅ No window management confusion
- ✅ Single window focus

### Code Quality
- ✅ Simpler architecture (no IPC)
- ✅ Easier to maintain (single codebase)
- ✅ Fewer dependencies
- ✅ Better testability
- ✅ Reduced complexity

### Performance
- ✅ No IPC overhead
- ✅ Faster dialog transitions
- ✅ Reduced memory footprint
- ✅ No multi-window synchronization issues

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Always-on-top for incoming calls | Use `windowManager.setAlwaysOnTop(true)` temporarily during call |
| User might miss incoming call | Use prominent banner with animation and sound |
| Form space too cramped | Use `insetPadding: EdgeInsets.all(16)` for maximum space |
| Platform code breakage | Test build on Windows and Linux after changes |
| Regression in existing features | Comprehensive testing checklist |

---

## Estimated Effort

- **Phase 1**: Account Setup Page - 2-3 hours
- **Phase 2**: Incoming Call Banner - 2-3 hours
- **Phase 3**: Infrastructure Removal - 1 hour
- **Phase 4**: Dependency Updates - 30 minutes
- **Phase 5**: Account Toggle (Accounts page) - 1 hour
- **Phase 6**: Update Callers - 30 minutes
- **Phase 7**: Increase Window Size - 15 minutes
- **Phase 8**: Switch Toggle + Long-Press Menu - 2 hours
- **Phase 9**: Platform Code - 1 hour
- **Testing & Bug Fixes**: 4-5 hours

**Total**: 14-16 hours

---

## Conclusion

This plan provides a complete roadmap for removing multi-window functionality and replacing it with single-window dialogs. The new approach will be simpler, faster, and provide better UX for a small softphone application.
