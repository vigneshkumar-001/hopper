# Quick Start - Logging System

## What's Ready

✅ **API Request/Response Logging** - All HTTP calls via Dio are automatically logged  
✅ **WebSocket Event Logging** - All socket.io events are captured  
✅ **App Crash Logging** - Unhandled exceptions and Flutter errors recorded  
✅ **Device Info Logging** - Captured on app startup  
✅ **Developer Logs Screen** - Full UI to view, export, copy, and clear logs  
✅ **Quick Export Button** - One-tap export from Ride Activity screen  

## How to Access Logs

### Method 1: Quick Export (Fastest)
1. Navigate to **Ride Activity** screen (from drawer)
2. Click the **blue download icon** 📥 in the header
3. Share logs via email/messaging app

### Method 2: Full Logs Screen
1. Navigate to **Ride Activity** screen
2. Click the **bug icon** 🐛 in the header
3. See all actions:
   - **View** all logs in terminal style
   - **Export** to share
   - **Copy** to clipboard
   - **Clear** logs with confirmation

## Log File Details

**Location:** `/data/data/com.hopper.driver/app_documents/hopper_dev_logs.txt`  
**Auto-tracked:**
- 📤 API requests (URL, method, headers, body)
- 📥 API responses (status, duration, body)
- 🔌 Socket events (connection, messages, disconnects)
- 💥 App crashes (exceptions, stack traces)
- 📱 Device info (model, OS version, SDK)

## Example Workflow

```
1. Reproduce an issue
2. Open Ride Activity → Click 📥 to export logs
3. Send logs to developer
4. Or click 🐛 to review logs instantly on device
```

## What Gets Logged Automatically

| Event | Logged | Location |
|-------|--------|----------|
| API calls (all) | ✅ | ApiLoggerInterceptor |
| Socket connect/disconnect | ✅ | SocketLoggerUtil |
| Ride requests | ✅ | Socket events |
| Location updates | ✅ | Socket events |
| App crashes | ✅ | main.dart |
| Device info | ✅ | App startup |

## Testing the System

### Test API Logging
1. Make any API call in the app
2. Open Logs screen
3. Look for `📤 API REQUEST` and `📥 API RESPONSE` entries

### Test Socket Logging
1. Stay in a ride (will emit socket events)
2. Open Logs screen
3. Look for `🔌 SOCKET EVENT` entries

### Test Crash Logging
1. (In dev only) Trigger an exception
2. Check logs for `💥 APP CRASH` entry

## File Format

Logs are plain text with timestamps:
```
[2025-06-24 10:12:01.234] [ERROR] User not found
[2025-06-24 10:12:02.156] 📤 API REQUEST...
[2025-06-24 10:12:03.789] 🔌 SOCKET EVENT: ride_request
```

## Troubleshooting

**No logs appearing?**
- App may not have made requests/socket events yet
- Check device has app_documents folder writable
- Try exporting to see if file exists

**Can't export?**
- Check device has file manager or email app
- Device may need file access permission granted

**Logs too large?**
- Click "Clear" in logs screen to start fresh
- Each log entry is timestamped for easy filtering

---

Ready to test! 🚀
