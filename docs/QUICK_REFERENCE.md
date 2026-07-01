# 🐛 Developer Logs - Quick Reference

## Access Developer Logs

### From Ride Activity Screen
```
┌─────────────────────────────────────────────────┐
│  ← Ride Activity                           🐛   │  ← TAP THIS BUTTON
└─────────────────────────────────────────────────┘
```

**Location**: Top right corner of Ride Activity screen
**Icon**: Bug icon (🐛) with grey background
**Action**: Single tap opens Developer Logs screen

---

## Developer Logs Screen Features

### 1. Log File Information
```
┌─────────────────────────────────────────────────┐
│                                                 │
│  Log File Size:              Development Only   │
│  2.45 MB                                        │
│                                                 │
└─────────────────────────────────────────────────┘
```

### 2. Action Buttons
```
┌─────────────────────────────────────────────────┐
│ [📥 Export] [📋 Copy] [🗑️ Clear]              │
└─────────────────────────────────────────────────┘
```

#### **Export** (Green Button)
- Taps: Download logs as `.txt` file
- Opens: Share dialog
- Can: Email, upload, or save to drive
- File Name: `hopper_dev_logs.txt`

#### **Copy** (Blue Button)
- Taps: Copy all logs to clipboard
- Shows: Confirmation toast
- Useful: Paste in messages or documents

#### **Clear** (Red Button)
- Taps: Shows confirmation dialog
- Requires: Confirmation to prevent accidents
- Result: All logs deleted, fresh start

### 3. Log Viewer
```
┌─────────────────────────────────────────────────┐
│                                                 │
│  ████████████████████████████████████████████  │
│  ░░ [2025-06-24 14:23:20.456] 📤 API REQUEST   │
│  ░░ URL: https://api.hoppr.com/rides           │
│  ░░ METHOD: GET                                │
│  ░░                                            │
│  ░░ [2025-06-24 14:23:21.890] 📥 API RESPONSE │
│  ░░ STATUS: 200                                │
│  ░░ DURATION: 1434ms                           │
│  ░░                                            │
│  ░░ [2025-06-24 14:23:25.123] 🔌 SOCKET EVENT │
│  ░░ EVENT: ride_request                        │
│  ░░                                            │
│  ████████████████████████████████████████████  │
│                                                 │
└─────────────────────────────────────────────────┘
```

**Features:**
- Terminal-style dark background
- Green monospace text
- Selectable text (long-press to select)
- Auto-scrolls to bottom
- Shows all logged events in order

---

## What Gets Logged Automatically

### 🌐 API Requests
```
[Timestamp] 📤 API REQUEST
URL: https://api.hoppr.com/endpoint
METHOD: GET/POST/PUT/DELETE
HEADERS: {...}
BODY: {...}
```

### 🌐 API Responses
```
[Timestamp] 📥 API RESPONSE
URL: https://api.hoppr.com/endpoint
STATUS: 200/400/500/etc
DURATION: 1234ms
BODY: {...}
```

### ❌ API Errors
```
[Timestamp] ❌ API ERROR
URL: https://api.hoppr.com/endpoint
ERROR: Connection timeout
ERROR BODY: {...}
```

### 🔌 Socket Events
```
[Timestamp] 🔌 SOCKET EVENT: event_name
DATA: {...}
```

### 📱 Navigation
```
[Timestamp] 📱 NAVIGATION: ScreenName
```

### 💥 App Crashes
```
╔═════════════════════════════════════════╗
║ [Timestamp] 💥 APP CRASH                ║
╚═════════════════════════════════════════╝
ERROR: Error message
STACK TRACE: Full stack trace...
```

### 📱 Device Info (At Startup)
```
[Timestamp] 📱 DEVICE INFO
MODEL: Samsung SM-G991B
MANUFACTURER: samsung
ANDROID VERSION: 12
SDK INT: 31
```

---

## Workflow Examples

### Export and Email Logs
```
1. Tap 🐛 icon from Ride Activity
   ↓
2. Developer Logs screen opens
   ↓
3. Tap [📥 Export] button
   ↓
4. Share dialog opens
   ↓
5. Select "Gmail" or "Email"
   ↓
6. Email logs to support team
```

### Copy Logs for Support Chat
```
1. Tap 🐛 icon from Ride Activity
   ↓
2. Developer Logs screen opens
   ↓
3. Tap [📋 Copy] button
   ↓
4. "Logs copied to clipboard" toast
   ↓
5. Open Slack/Teams/WhatsApp
   ↓
6. Long press → Paste logs
   ↓
7. Send to support team
```

### Clear Logs to Start Fresh
```
1. Tap 🐛 icon from Ride Activity
   ↓
2. Developer Logs screen opens
   ↓
3. Tap [🗑️ Clear] button
   ↓
4. Confirmation dialog appears
   ↓
5. Tap "Clear" to confirm
   ↓
6. "Logs cleared successfully" toast
   ↓
7. Logs screen is now empty
```

---

## Real-Time Testing Workflow

### Test API Logging
```
1. Open Developer Logs screen (🐛 button)
2. Make an API call in your app
   - Tap "Request Ride"
   - Load user profile
   - Fetch ride history
   - Any API call
3. Logs appear immediately in logs screen
4. Check for: URL, METHOD, STATUS, DURATION
```

### Test Socket Logging
```
1. Open Developer Logs screen
2. Trigger a socket event
   - Accept a ride
   - Send a message
   - Update ride status
3. Check for: 🔌 SOCKET EVENT entries
4. Verify event name and data
```

### Test Crash Logging
```
1. Make app crash intentionally (dev only)
2. Restart app
3. Open Developer Logs screen
4. Check for: 💥 APP CRASH entry
5. Verify error message and stack trace
```

---

## Button Locations

### Ride Activity Screen
```
Top Navigation Bar:
┌─────────────────────────────────────────────┐
│  [←] Ride Activity [→] [🐛]                │
│      (back)        (spacer)  (debug logs)   │
└─────────────────────────────────────────────┘

🐛 Location: Top-right corner
Style: Grey background, grey icon
Size: 32x32 pixels
```

### Developer Logs Screen
```
Top Bar:
┌─────────────────────────────────────────────┐
│  [←] Developer Logs                         │
│      (back)                                 │
└─────────────────────────────────────────────┘

Action Buttons (Below log info):
┌─────────────────────────────────────────────┐
│ [Export] [Copy] [Clear]                     │
│  (green)  (blue) (red)                      │
└─────────────────────────────────────────────┘

Log Viewer (Entire remaining screen):
┌─────────────────────────────────────────────┐
│ [Dark terminal-style log display]           │
│ [Scrollable]                                │
│ [Shows all logs]                            │
└─────────────────────────────────────────────┘
```

---

## Troubleshooting Quick Tips

### Logs Not Appearing?
- Make sure you did `flutter pub get`
- Restart app with hot restart (R) or cold start
- Check that your API calls are actually being made

### Export Button Not Working?
- Ensure you have storage permissions
- Try using "Copy" button instead
- Check device storage space

### Logs Appear as Empty?
- App just started - make some API calls
- Use "Clear" button and then trigger actions
- Reload logs screen

### Screen Won't Load?
- Go back and re-enter the screen
- Check logs are being generated
- Restart app if needed

---

## File Format

### Exported Log File
```
Filename: hopper_dev_logs.txt
Location: Downloads folder (or share dialog)
Format: Plain text (.txt)
Size: Typically 100KB - 5MB
Encoding: UTF-8
Readable: Yes, with any text editor
Shareable: Yes, via email, cloud, etc
```

### Log Entries Format
```
[YYYY-MM-DD HH:mm:ss.SSS] [TYPE] Message
[YYYY-MM-DD HH:mm:ss.SSS] 📤 API REQUEST
[YYYY-MM-DD HH:mm:ss.SSS] 📥 API RESPONSE
[YYYY-MM-DD HH:mm:ss.SSS] ❌ API ERROR
[YYYY-MM-DD HH:mm:ss.SSS] 🔌 SOCKET EVENT
[YYYY-MM-DD HH:mm:ss.SSS] 📱 NAVIGATION
[YYYY-MM-DD HH:mm:ss.SSS] 💥 APP CRASH
```

---

## Performance Notes

- **Log File Size**: Typically grows ~100KB per hour of active use
- **Memory Impact**: Minimal (< 1MB)
- **UI Responsiveness**: No impact
- **Best Practice**: Clear logs weekly during development

---

## Commands for Developers

### Force Run pub get
```bash
flutter pub get
```

### Run app with logging
```bash
flutter run
```

### Clean and rebuild (if issues)
```bash
flutter clean
flutter pub get
flutter run
```

---

## Video Walkthrough (If Made)

```
1. Show Ride Activity screen
   - Point to 🐛 button location
   
2. Tap 🐛 button
   - Show transition to Developer Logs
   
3. Make API call
   - Show logs appearing in real-time
   
4. Tap Export
   - Show share dialog
   
5. Tap Copy
   - Show confirmation toast
   
6. Tap Clear
   - Show confirmation dialog
   - Show cleared logs
```

---

## Summary

| Feature | How to Use | Button |
|---------|-----------|--------|
| **View Logs** | Tap 🐛 in Ride Activity | 🐛 |
| **Export Logs** | Tap Export button | 📥 |
| **Copy Logs** | Tap Copy button | 📋 |
| **Clear Logs** | Tap Clear → Confirm | 🗑️ |
| **Go Back** | Tap back arrow or swipe | ← |

---

## That's It! 🎉

You're ready to start debugging with professional logs!

**Remember**: This is for development only. Logs contain sensitive data, so don't share them publicly.
