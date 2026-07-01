# Developer Logging System - Setup Guide

This is a comprehensive developer logging system for the Hopper Driver app that captures API requests, responses, socket events, crashes, and device information. All logs are saved to a file and can be exported from the app.

## Features

✅ **API Request/Response Logging**
- Captures all HTTP requests with method, URL, headers, and body
- Logs all responses with status code, body, and duration
- Tracks API errors with error details

✅ **Socket Event Logging**
- Logs all WebSocket connections and disconnections
- Captures all socket events and their data
- Logs socket emissions with data

✅ **App Crash Logging**
- Captures Flutter errors
- Logs unhandled exceptions with stack traces
- Automatically saves to file for later review

✅ **Device Information**
- Logs device model, manufacturer, Android version, SDK version
- Captured at app startup

✅ **File Export & Management**
- Export logs as `.txt` file (shareable via email, Slack, etc.)
- Copy logs to clipboard for quick sharing
- Clear logs when needed
- View log file size

## Files Created

```
lib/
├── Core/Services/
│   ├── logger_service.dart           # Main logging service
│   └── socket_logger_util.dart       # Socket.IO logging utilities
├── api/interceptors/
│   └── api_logger_interceptor.dart   # Dio API interceptor
└── Presentation/Drawer/screens/
    └── dev_logs_screen.dart          # UI for viewing/managing logs
```

## Setup Instructions

### 1. ✅ Already Done - Dependencies Added

The following dependencies have been added to `pubspec.yaml`:
```yaml
dependencies:
  logger: ^2.5.0              # Already present
  path_provider: ^2.1.5       # ✅ Added
  share_plus: ^10.0.0         # ✅ Added
  device_info_plus: ^11.0.0   # ✅ Added
```

### 2. ✅ Already Done - Main.dart Updated

The main.dart has been updated to:
- Initialize the logging service at app startup
- Log device information
- Setup error/crash handlers
- Wrap app in error zone

```dart
import 'package:hopper/Core/Services/logger_service.dart';

// In main()
final loggerService = LoggerService();
await loggerService.logDeviceInfo();

FlutterError.onError = (details) {
  loggerService.logAppCrash(
    details.exceptionAsString(),
    details.stack ?? StackTrace.current,
  );
};

runZonedGuarded(() {
  runApp(const MyApp());
}, (error, stack) {
  loggerService.logAppCrash(error.toString(), stack);
});
```

### 3. ✅ Already Done - API Logging Setup

The `api/repository/request.dart` has been updated to add the `ApiLoggerInterceptor` to all Dio instances:

```dart
import 'package:hopper/api/interceptors/api_logger_interceptor.dart';

// In sendRequest(), formData(), and sendGetRequest()
Dio dio = Dio(...);
dio.interceptors.add(ApiLoggerInterceptor());  // ✅ Already added
dio.interceptors.add(InterceptorsWrapper(...));
```

## Usage Examples

### Basic Logging

```dart
import 'package:hopper/Core/Services/logger_service.dart';

final loggerService = LoggerService();

// Log a simple message
await loggerService.log("User started a ride");

// Log with level
await loggerService.log("Ride request sent", level: 'INFO');

// Log errors
try {
  // some code
} catch (e, st) {
  await loggerService.logError("Failed to load rides", e, st);
}
```

### Navigation Logging

```dart
import 'package:hopper/Core/Services/logger_service.dart';

class RouteLogger extends NavigatorObserver {
  @override
  void didPush(Route route, Route? previousRoute) {
    final loggerService = LoggerService();
    loggerService.logNavigation(route.settings.name ?? 'Unknown');
  }
}

// Register in MaterialApp
MaterialApp(
  navigatorObservers: [RouteLogger()],
  // ...
)
```

### Socket.IO Logging

```dart
import 'package:hopper/Core/Services/socket_logger_util.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

// Setup logging for socket
io.Socket socket = io.io('your-server-url');
SocketLoggerUtil.setupSocketLogging(socket);

// Emit events with logging
SocketLoggerUtil.emitWithLogging(socket, 'ride_request', {
  'rideId': '123',
  'startLocation': '...',
});

// Or manually log socket events
final loggerService = LoggerService();
loggerService.logSocketEvent(
  eventName: 'ride_update',
  data: {'status': 'in_progress'},
);
```

### Export Logs

```dart
import 'package:hopper/Core/Services/logger_service.dart';
import 'package:share_plus/share_plus.dart';

final loggerService = LoggerService();

// Export logs file
final file = await loggerService.exportLogs();
await Share.shareXFiles([XFile(file.path)]);

// Or get logs as string
final logsContent = await loggerService.getLogsContent();
print(logsContent);

// Get file size
final size = await loggerService.getLogSize();
print('Log file size: $size');

// Clear logs
await loggerService.clearLogs();
```

## Accessing Developer Logs in App

1. **From Ride Activity Screen**: Tap the 🐛 icon in the top-right corner
2. **Programmatically**: 
   ```dart
   Navigator.push(
     context,
     MaterialPageRoute(builder: (context) => const DevLogsScreen()),
   );
   ```

## Developer Logs Screen Features

- **Export Button**: Download logs as `.txt` file (can email or upload)
- **Copy Button**: Copy all logs to clipboard
- **Clear Button**: Clear all logs (with confirmation)
- **Live View**: Terminal-style log viewer with syntax highlighting
- **File Size**: Shows current log file size

## Log File Location

Logs are stored in the app's documents directory:
```
/data/data/com.hoppr.driver/files/hopper_dev_logs.txt
```

On debug, you can access via:
```dart
final dir = await getApplicationDocumentsDirectory();
final filePath = '${dir.path}/hopper_dev_logs.txt';
```

## Example Log Output

```
[2025-06-24 14:23:15.123] [INFO] 📱 DEVICE INFO
MODEL: SM-G991B
MANUFACTURER: samsung
ANDROID VERSION: 12
SDK INT: 31

[2025-06-24 14:23:20.456] 📤 API REQUEST
URL: https://api.hoppr.com/rides
METHOD: GET
HEADERS: {Authorization: Bearer token123}

[2025-06-24 14:23:21.890] 📥 API RESPONSE
URL: https://api.hoppr.com/rides
STATUS: 200
DURATION: 1434ms
BODY: {rides: [...]}

[2025-06-24 14:23:25.123] 🔌 SOCKET EVENT: ride_request
DATA: {rideId: '456', type: 'single'}

[2025-06-24 14:23:30.456] 📱 NAVIGATION: RideDetailScreen
```

## Best Practices

1. **Don't log sensitive data** in production:
   ```dart
   // ❌ Bad
   loggerService.log("User token: $token");
   
   // ✅ Good
   loggerService.log("User authenticated");
   ```

2. **Use appropriate log levels**:
   - `INFO`: General information
   - `DEBUG`: Detailed debugging information
   - `ERROR`: Error conditions
   - `WARNING`: Warning messages

3. **Export logs regularly** during development to track issues

4. **Clear logs** when they get too large to improve performance

## Troubleshooting

### Logs not appearing
- Ensure `pubspec.yaml` has been updated with new dependencies
- Run `flutter pub get` to install new packages
- Restart the app after changes

### Export not working
- Ensure `share_plus` has proper Android permissions in `AndroidManifest.xml`
- Check app storage permissions are granted

### File size growing too large
- Use the "Clear" button in Developer Logs screen
- Implement log rotation (optional enhancement)

## Future Enhancements

1. **Log Rotation**: Automatically archive logs when size exceeds limit
2. **Upload to Server**: Send logs directly to analytics backend
3. **Filtering**: Filter logs by type (API, Socket, Navigation, etc.)
4. **Search**: Search logs for specific keywords
5. **Time Range**: Filter logs by date/time range
6. **Crash Analytics**: Automatic crash reporting to backend

## Testing

To test the logging system:

1. **Test API Logging**: Make any API call - check logs for request/response
2. **Test Socket Logging**: Trigger socket events - verify they appear in logs
3. **Test Crash Logging**: Throw an error - check logs for crash details
4. **Test Export**: Export logs and verify file contains all recent logs
5. **Test Clear**: Clear logs and verify logs screen is empty

## Integration Checklist

- ✅ Dependencies added to pubspec.yaml
- ✅ LoggerService created (lib/Core/Services/logger_service.dart)
- ✅ ApiLoggerInterceptor created (lib/api/interceptors/api_logger_interceptor.dart)
- ✅ SocketLoggerUtil created (lib/Core/Services/socket_logger_util.dart)
- ✅ DevLogsScreen created (lib/Presentation/Drawer/screens/dev_logs_screen.dart)
- ✅ main.dart updated with logger initialization and error handling
- ✅ api/repository/request.dart updated with API interceptor
- ✅ RideActivity screen updated with debug button to access logs

## Questions?

For questions or issues with the logging system, refer back to this guide or check the LoggerService implementation for additional methods.
