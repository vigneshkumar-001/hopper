# 📊 Hopper Log System - Complete Guide

## Overview
The log system automatically tracks:
- ✅ API calls (request, response, status codes)
- ✅ Socket events (connection, messages, errors)
- ✅ Rider actions (added, updated, arrived, onboard, dropped)
- ✅ Location updates (GPS, socket updates)
- ✅ Errors & warnings

---

## 1. Quick Start

### Import
```dart
import 'package:hopper/Core/Services/log_manager.dart';

final logManager = LogManager();
```

### Basic Logging
```dart
// Log API call
logManager.logApi(
  method: 'GET',
  endpoint: '/api/rides',
  response: {'rides': [...]},
  statusCode: 200,
  bookingId: 'booking_123',
);

// Log socket event
logManager.logSocket(
  event: 'share-ride-request',
  data: riderData,
  bookingId: 'booking_123',
);

// Log rider action
logManager.logRider(
  action: 'RIDER_ADDED',
  bookingId: 'booking_123',
  riderData: {'name': 'John', 'phone': '+1234567890'},
);

// Log error
logManager.logError(
  'Failed to fetch route',
  bookingId: 'booking_123',
  stackTrace: e.toString(),
);
```

---

## 2. Integration Points

### API Calls (dio_interceptor / api_client)
```dart
// In your API interceptor:

@override
void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
  logManager.logApi(
    method: options.method,
    endpoint: options.path,
    request: options.data,
  );
  handler.next(options);
}

@override
void onResponse(Response response, ResponseInterceptorHandler handler) {
  logManager.logApi(
    method: response.requestOptions.method,
    endpoint: response.requestOptions.path,
    response: response.data,
    statusCode: response.statusCode,
  );
  handler.next(response);
}

@override
void onError(DioException err, ErrorInterceptorHandler handler) {
  logManager.logApi(
    method: err.requestOptions.method,
    endpoint: err.requestOptions.path,
    statusCode: err.response?.statusCode,
    error: err.toString(),
  );
  handler.next(err);
}
```

### Socket Events (socket_io_client.dart)
```dart
// In socketService initialization:

socketService.socket.onAny((event, data) {
  logManager.logSocket(
    event: event,
    data: data,
    bookingId: currentBookingId, // if available
  );
});

// For specific events:
socketService.on('share-ride-request', (data) {
  logManager.logSocket(
    event: 'SHARE_RIDE_REQUEST',
    data: data,
    bookingId: data['bookingId'],
  );
  // Process the rider...
});
```

### Location Updates
```dart
// In GPS/location service:

onLocationChange: (position) {
  logManager.logLocation(
    latitude: position.latitude,
    longitude: position.longitude,
    source: 'GPS',
    bookingId: currentBookingId,
  );
};

// In socket location update:
logManager.logLocation(
  latitude: data['lat'],
  longitude: data['lng'],
  source: 'socket',
  bookingId: bookingId,
);
```

---

## 3. Access Log Viewer

### Option A: Add Debug Button
```dart
// In your main driver screen:

floatingActionButton: FloatingActionButton(
  child: const Icon(Icons.description),
  onPressed: () => Get.to(() => const LogViewerScreen()),
),
```

### Option B: Add Menu Option
```dart
// In settings/menu:
ListTile(
  leading: const Icon(Icons.bug_report),
  title: const Text('View Logs'),
  onTap: () => Get.to(() => const LogViewerScreen()),
),
```

---

## 4. Features

### Viewing Logs
- **Filter by Type**: API, Socket, Rider, Location, Error
- **Search**: Find logs by event name or booking ID
- **View Details**: Expand any log to see full data and error stack traces
- **Real-time Stats**: See counts by type at the top

### Exporting Logs
```dart
// Export as JSON
await logManager.shareLogsAsFile('json');

// Export as CSV
await logManager.shareLogsAsFile('csv');

// Export as TXT
await logManager.shareLogsAsFile('txt');
```

Files are saved to: `/data/data/com.hopper.driver/documents/hopper_logs/`

### Retrieving Logs Programmatically
```dart
// Get all logs
final allLogs = logManager.getAllLogs();

// Get by type
final apiLogs = logManager.getLogsByType(LogType.api);

// Get by booking ID
final riderLogs = logManager.getLogsByBooking('booking_123');

// Get recent
final recent = logManager.getRecentLogs(count: 50);

// Get errors only
final errors = logManager.getErrorLogs();

// Get statistics
final stats = logManager.getLogStats();
print(stats); // {'api': 42, 'socket': 128, 'error': 3, ...}
```

---

## 5. Cleanup

### Clear Memory
```dart
logManager.clearMemoryLogs();
```

### Clear Old Files
```dart
// Clear files older than 7 days
await logManager.clearOldLogFiles(daysToKeep: 7);
```

### Auto-cleanup
Add to your app initialization:
```dart
void initState() {
  super.initState();
  // Clean up logs older than 14 days on app start
  logManager.clearOldLogFiles(daysToKeep: 14);
}
```

---

## 6. Best Practices

### ✅ DO
- Log all API calls (before + after)
- Log all socket events
- Log rider state changes (added, arrived, onboard, dropped)
- Log errors with stack traces
- Use bookingId when available for filtering

### ❌ DON'T
- Log sensitive data (passwords, tokens, API keys)
- Log entire user objects (use specific fields only)
- Ignore connection errors
- Clear logs before investigating issues

---

## 7. Example Workflow

### Scenario: "Why aren't multiple riders being added?"

1. **Open Log Viewer**
   ```
   Get.to(() => const LogViewerScreen())
   ```

2. **Filter by "Rider" type**
   - See all `RIDER_ADDED` events
   - Check timestamps
   - Verify booking IDs

3. **Filter by "Socket" type**
   - See all socket events
   - Check if `share-ride-request` events are received
   - Look for disconnection events

4. **Export logs**
   - Export as JSON for analysis
   - Send to backend team for debugging

5. **Find the issue**
   ```
   Log data shows:
   - ✅ Socket connected
   - ❌ No RIDER_ADDED after 3 minutes
   - ✅ Socket events received (location updates)
   
   Conclusion: Backend not sending share-ride-request events
   ```

---

## 8. Log Storage

### Location
- **Memory**: Keeps last 5000 logs in RAM
- **Disk**: `/Documents/hopper_logs/hopper_YYYY-MM-DD.log`

### File Format
Each line is a JSON object:
```json
{
  "timestamp": "2026-06-23T11:41:30.123Z",
  "type": "rider",
  "event": "RIDER_ADDED",
  "bookingId": "booking_123",
  "data": "{'name': 'John', 'totalRiders': 2}",
  "error": null
}
```

---

## 9. Troubleshooting

### Logs not appearing in UI?
- Check if log writes are async (don't block UI)
- Verify logManager is singleton (shared across app)
- Check Device → Logcat for any file I/O errors

### Export not working?
- Verify storage permissions (WRITE_EXTERNAL_STORAGE)
- Check if temp directory exists
- Try exporting to a different format

### Memory growing too large?
- Adjust `maxLogs` in LogManager (default: 5000)
- Call `clearMemoryLogs()` periodically
- Call `clearOldLogFiles()` on app startup

---

## 10. Quick Reference

```dart
// Main log methods
logManager.log(type: LogType.api, event: 'GET /rides', data: {...});
logManager.logApi(method: 'GET', endpoint: '/rides', response: {...});
logManager.logSocket(event: 'update', data: {...});
logManager.logRider(action: 'ADDED', bookingId: 'b123', riderData: {...});
logManager.logLocation(latitude: 12.34, longitude: 56.78);
logManager.logError('Failed!', bookingId: 'b123');

// Retrieval
logManager.getAllLogs();
logManager.getLogsByType(LogType.api);
logManager.getLogsByBooking('b123');
logManager.getRecentLogs(count: 50);
logManager.getErrorLogs();
logManager.getLogStats();

// Export
await logManager.exportAsJson();
await logManager.exportAsCsv();
await logManager.exportAsText();
await logManager.shareLogsAsFile('json');

// Cleanup
logManager.clearMemoryLogs();
await logManager.clearOldLogFiles(daysToKeep: 7);
```

---

**Happy debugging! 🚀**
