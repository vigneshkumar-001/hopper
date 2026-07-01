# Hopper Driver - Professional Developer Logging System

## Overview
A comprehensive logging system has been implemented for the Hopper Driver Flutter app to capture all development-critical information for debugging and testing.

## Features Implemented

### 1. **Central Logger Service**
**Location:** `lib/Core/Services/logger_service.dart`

The main logging service that handles:
- All log writes to file (`hopper_dev_logs.txt`)
- Formatted timestamps
- Log size management
- Export and clear operations

**Key Methods:**
```dart
// Basic logging
Future<void> log(String message, {String level = 'INFO'})

// Error logging
Future<void> logError(String message, dynamic error, StackTrace? stackTrace)

// API logging
Future<void> logApiRequest({required String url, required String method, ...})
Future<void> logApiResponse({required String url, required int statusCode, ...})
Future<void> logApiError({required String url, required String error, ...})

// Socket logging
Future<void> logSocketEvent({required String eventName, dynamic data})

// Navigation logging
Future<void> logNavigation(String screenName)

// Device info logging
Future<void> logDeviceInfo()

// Crash logging
Future<void> logAppCrash(String error, StackTrace stackTrace)

// Export/Clear
Future<File> exportLogs()
Future<String> getLogsContent()
Future<void> clearLogs()
Future<String> getLogSize()
```

### 2. **API Request/Response Logging**
**Location:** `lib/api/interceptors/api_logger_interceptor.dart`

Automatically logs:
- ✅ All API requests (URL, method, headers, body)
- ✅ All API responses (status code, duration, response body)
- ✅ All API errors with error details

**Integrated with:** Dio HTTP client (automatically added to all API calls)

**Features:**
- Tracks request-response duration in milliseconds
- Captures error bodies for failed requests
- All logs include formatted timestamps

### 3. **Socket Event Logging**
**Location:** `lib/Core/Services/socket_logger_util.dart`

Logs all WebSocket events:
- ✅ Socket connection/disconnection
- ✅ Connect/disconnect errors
- ✅ All socket events (`onAny` listener)
- ✅ Socket emissions with data

**Integrated with:** Socket.IO client in `lib/utils/websocket/socket_io_client.dart`

**Events Captured:**
- `SOCKET_CONNECTED`
- `SOCKET_DISCONNECTED`
- `SOCKET_CONNECT_ERROR`
- `SOCKET_ERROR`
- All custom events (e.g., `ride_request`, `updateLocation`, etc.)

### 4. **App Crash & Error Logging**
**Location:** `lib/main.dart`

Captures:
- ✅ Flutter framework errors
- ✅ Unhandled exceptions
- ✅ Stack traces

Setup in main():
```dart
FlutterError.onError = (details) {
  loggerService.logAppCrash(
    details.exceptionAsString(),
    details.stack ?? StackTrace.current,
  );
};

runZonedGuarded(() {
  runApp(MyApp());
}, (error, stack) {
  loggerService.logAppCrash(error.toString(), stack);
});
```

### 5. **Navigation Logging**
Ready to implement in navigation observers. Currently integrated in the logging service.

### 6. **Device Information Logging**
**Location:** `lib/Core/Services/logger_service.dart`

Captures:
- Device model
- Manufacturer
- Android version
- SDK level
- Device name

Logged at app startup in `main.dart`:
```dart
await loggerService.logDeviceInfo();
```

### 7. **Developer Logs Screen**
**Location:** `lib/Presentation/Drawer/screens/dev_logs_screen.dart`

A dedicated screen for developers to:
- 📋 **View** - See all logs in a terminal-like interface
- 📥 **Copy** - Copy logs to clipboard
- 📤 **Export** - Share logs as a `.txt` file
- 🗑️ **Clear** - Delete all logs (with confirmation)

**Access:** 
- From Ride Activity screen → Click the 🐛 (bug) icon
- From Drawer menu (if configured)

### 8. **Quick Export Button on Ride Activity**
**Location:** `lib/Presentation/Drawer/screens/ride_activity.dart`

Added a quick export logs button (blue download icon 📥) to the Ride Activity page header for easy access to:
- Export current logs
- Navigate to full dev logs screen

## Log File Location

Logs are stored at:
```
/data/data/com.hopper.driver/app_documents/hopper_dev_logs.txt
```

## Log Output Examples

### API Request
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[2025-06-24 10:12:01.234] 📤 API REQUEST
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
URL: https://bck.myhoppr.com/api/booking/details
METHOD: GET
HEADERS: {Authorization: Bearer abc123...}
BODY: null
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### API Response
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[2025-06-24 10:12:02.156] 📥 API RESPONSE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
URL: https://bck.myhoppr.com/api/booking/details
STATUS: 200
DURATION: 922ms
BODY: {bookingId: 123, status: "ACCEPTED", ...}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Socket Event
```
[2025-06-24 10:12:05.333] 🔌 SOCKET EVENT: ride_request
DATA: {rideId: 456, pickupLocation: {lat: 28.1234, lng: 77.5678}}
```

### App Crash
```
╔═════════════════════════════════════════════════╗
║ [2025-06-24 10:15:30.999] 💥 APP CRASH         ║
╚═════════════════════════════════════════════════╝
ERROR: Null check operator used on a null value
STACK TRACE:
  #0 MyClass.methodName (package:hopper/path/file.dart:42)
  #1 ...
════════════════════════════════════════════════════════
```

## How to Use

### For Developers

**1. Access Logs During Development:**
   - Open the Ride Activity screen
   - Click the blue download icon 📥 to quickly export logs
   - Or click the bug icon 🐛 to view full logs screen

**2. View Logs in Real-Time:**
   - Navigate to the Developer Logs screen (Ride Activity → 🐛 icon)
   - Scroll through all captured events
   - Check timestamps and duration for API calls

**3. Export Logs:**
   - Open Dev Logs Screen
   - Click "Export" button
   - Share the file via email, Slack, or file transfer

**4. Clear Logs:**
   - Open Dev Logs Screen
   - Click "Clear" button
   - Confirm deletion

**5. Copy Logs:**
   - Open Dev Logs Screen
   - Click "Copy" button
   - Paste into debugger or text editor

### For Testing

- **API Testing:** Export logs to verify all requests/responses match expected behavior
- **Socket Testing:** Check WebSocket event sequence and timing
- **Error Testing:** Verify crash logs capture all error details
- **Performance Testing:** Check API response durations from logs

## Configuration

### Log File Size Limit
Currently unlimited. In production, you may want to add:
```dart
// In logger_service.dart
Future<void> _writeToFile(String message) async {
  final file = File(filePath);
  final size = await file.length();
  if (size > 50 * 1024 * 1024) { // 50MB limit
    await file.delete();
  }
  // ... write message
}
```

### Console Output
All logs are also printed to the console using the `logger` package for real-time debugging.

## Integration Points

✅ **Already Integrated:**
- ✅ API Interceptor (Dio)
- ✅ Socket Logger (Socket.IO)
- ✅ Crash Handler (Flutter)
- ✅ Device Info Logger (App startup)

⚠️ **Optional Integrations:**
- Navigation logging (add to navigation observers if needed)
- Custom event logging throughout the app

## Dependencies Used

```yaml
logger: ^2.4.0              # Console logging with pretty printer
path_provider: ^2.1.5       # File system access
share_plus: ^10.0.0         # Share logs functionality
dio: ^5.7.0                 # HTTP client with interceptors
device_info_plus: ^11.0.0   # Device information
socket_io_client: ^2.0.0    # WebSocket client
```

## Best Practices

1. **Clear Logs Regularly** - Don't let logs grow too large
2. **Export Before Testing** - Save baseline logs before making changes
3. **Check Duration Metrics** - API response times help identify performance issues
4. **Look for Error Patterns** - Repeated errors indicate systemic issues
5. **Monitor Socket Events** - Check for unexpected disconnect/reconnect cycles

## Troubleshooting

### Logs Not Appearing
- Check if `LoggerService` is initialized in `main.dart`
- Verify file write permissions in AndroidManifest.xml
- Check device storage space

### Export Not Working
- Verify `share_plus` package permissions
- Check if device has a file manager installed

### Missing API Logs
- Confirm `ApiLoggerInterceptor` is added to Dio client
- Check if API calls are actually being made
- Verify network connectivity

## Future Enhancements

- [ ] Automatic log rotation when size limit reached
- [ ] Color-coded console output for different log levels
- [ ] Network performance analytics from logs
- [ ] Remote log upload to server
- [ ] Log filtering by event type
- [ ] Search functionality in dev logs screen

---

**Last Updated:** 2025-06-24  
**Version:** 1.0.0  
**Status:** Production Ready for Development/Testing
