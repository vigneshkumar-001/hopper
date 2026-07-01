# 📝 Developer Logging - Code Snippets

Copy and paste these snippets to add logging to your code.

---

## Import Logger Service

Add to top of your file:
```dart
import 'package:hopper/Core/Services/logger_service.dart';
```

---

## Basic Logging

### Simple Log Message
```dart
final logger = LoggerService();
await logger.log("User tapped accept ride button");
```

### Log with Info Level
```dart
await logger.log("Fetching ride details", level: 'INFO');
```

### Log with Debug Level
```dart
await logger.log("Processing payment data", level: 'DEBUG');
```

---

## Error Logging

### Catch Exception and Log
```dart
try {
  // Some code that might fail
  await fetchUserData();
} catch (e, st) {
  await logger.logError("Failed to fetch user data", e, st);
}
```

### Log Network Error
```dart
try {
  await apiRequest();
} catch (error) {
  await logger.logError(
    "Network request failed", 
    error,
    StackTrace.current
  );
}
```

---

## Navigation Logging

### Add Route Logger to MaterialApp
```dart
import 'package:hopper/Core/Services/logger_service.dart';

class RouteLogger extends NavigatorObserver {
  final logger = LoggerService();

  @override
  void didPush(Route route, Route? previousRoute) {
    logger.logNavigation(route.settings.name ?? 'Unknown Screen');
  }
}

// In MyApp or home widget:
MaterialApp(
  navigatorObservers: [RouteLogger()],
  home: SplashScreen(),
  // ... rest of config
)
```

### Manual Navigation Log
```dart
final logger = LoggerService();
await logger.logNavigation("HomeScreen");
```

---

## API Logging

### Automatic Logging (Already Setup!)
```dart
// No code needed! Just make your API calls normally
// All requests/responses are auto-logged

await dio.get('/rides');  // ✅ Automatically logged
```

### Manual API Log (if needed)
```dart
final logger = LoggerService();

// Log custom API
await logger.logApiRequest(
  url: 'https://api.example.com/custom',
  method: 'POST',
  headers: {'Authorization': 'Bearer token'},
  body: {'key': 'value'},
);

// Log response
await logger.logApiResponse(
  url: 'https://api.example.com/custom',
  statusCode: 200,
  body: {'result': 'success'},
  durationMs: 1234,
);

// Log error
await logger.logApiError(
  url: 'https://api.example.com/custom',
  error: 'Connection timeout',
  errorBody: {'error': 'Request failed'},
);
```

---

## Socket Event Logging

### Setup Socket with Logging
```dart
import 'package:hopper/Core/Services/socket_logger_util.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

// Create socket
io.Socket socket = io.io(
  'https://your-server.com',
  io.OptionBuilder().setTransports(['websocket']).build(),
);

// Setup logging (one time)
SocketLoggerUtil.setupSocketLogging(socket);
```

### Emit Event with Logging
```dart
// Emit and automatically log
await SocketLoggerUtil.emitWithLogging(
  socket,
  'accept_ride',
  {
    'rideId': rideId,
    'driverId': driverId,
    'timestamp': DateTime.now(),
  },
);
```

### Manual Socket Log
```dart
final logger = LoggerService();

// Log incoming event
await logger.logSocketEvent(
  eventName: 'ride_completed',
  data: {'rideId': '123', 'rating': 5},
);

// Log outgoing event
await logger.logSocketEvent(
  eventName: '🔌 EMIT: start_ride',
  data: {'rideId': '123'},
);
```

---

## Device Information

### Log Device Info (Auto on Startup)
```dart
// Already called in main.dart!
// To manually call:

final logger = LoggerService();
await logger.logDeviceInfo();
```

---

## Export/Share Logs

### Export Logs as File
```dart
import 'package:share_plus/share_plus.dart';

final logger = LoggerService();

// Get the log file
final logFile = await logger.exportLogs();

// Share it
await Share.shareXFiles([XFile(logFile.path)]);
```

### Get Logs as String
```dart
final logger = LoggerService();

// Get all logs as text
final logsContent = await logger.getLogsContent();

// Print or use as needed
print(logsContent);

// Or copy to clipboard
await Clipboard.setData(ClipboardData(text: logsContent));
```

### Get Log File Size
```dart
final logger = LoggerService();

final size = await logger.getLogSize();
print('Log file size: $size');  // e.g., "2.45 MB"
```

### Clear Logs
```dart
final logger = LoggerService();

await logger.clearLogs();
print('Logs cleared');
```

---

## Common Use Cases

### Log Ride Accept
```dart
void acceptRide(String rideId) async {
  final logger = LoggerService();
  
  await logger.log("Driver accepted ride: $rideId");
  
  try {
    await socket.emit('accept_ride', {'rideId': rideId});
    await logger.log("Ride acceptance sent to server");
  } catch (e, st) {
    await logger.logError("Failed to accept ride", e, st);
  }
}
```

### Log User Login
```dart
void loginUser(String phone) async {
  final logger = LoggerService();
  
  await logger.log("Login attempt for: $phone");
  
  try {
    final response = await dio.post('/auth/login', data: {'phone': phone});
    await logger.log("Login successful");
  } catch (e, st) {
    await logger.logError("Login failed", e, st);
  }
}
```

### Log Payment Processing
```dart
void processPayment(double amount) async {
  final logger = LoggerService();
  
  await logger.log("Processing payment: NGN $amount");
  
  try {
    // Payment processing code
    await logger.log("Payment processed successfully");
  } catch (e, st) {
    await logger.logError("Payment processing failed", e, st);
  }
}
```

### Log Screen Transitions
```dart
void goToRideDetails(String rideId) async {
  final logger = LoggerService();
  
  await logger.logNavigation("RideDetailsScreen($rideId)");
  
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => RideDetailsScreen(rideId: rideId),
    ),
  );
}
```

---

## Debug Print vs Logger

### ❌ Don't Use Debug Print
```dart
// BAD - Won't be logged to file
print("User clicked button");
```

### ✅ Use Logger Service
```dart
// GOOD - Logged to file, visible in Developer Logs
await logger.log("User clicked button");
```

---

## Logging Levels Guide

```dart
// LEVEL 1: General Information
await logger.log("Ride started", level: 'INFO');

// LEVEL 2: Detailed Debugging
await logger.log("Processing data", level: 'DEBUG');

// LEVEL 3: Error Conditions
await loggerService.logError("Failed to load data", error, stackTrace);

// LEVEL 4: API Errors
await logger.logApiError(
  url: 'https://api.hoppr.com/rides',
  error: 'Server Error',
  errorBody: responseBody,
);
```

---

## One-Liners

### Quick Log
```dart
LoggerService().log("Event happened");
```

### Log and Print
```dart
final msg = "Something happened";
LoggerService().log(msg);
print(msg);
```

### Log in Widget
```dart
@override
void initState() {
  super.initState();
  LoggerService().log("${runtimeType} initialized");
}
```

---

## Avoid Logging

### ❌ Don't Log Sensitive Data
```dart
// BAD
await logger.log("User password: $password");
await logger.log("Credit card: $cardNumber");
await logger.log("API Key: $apiKey");
```

### ✅ Log Safely
```dart
// GOOD
await logger.log("User authenticated successfully");
await logger.log("Payment method updated");
await logger.log("API request sent");
```

---

## Performance Tips

### 1. Avoid Logging in Loops
```dart
// ❌ BAD - Logs every item
for (var ride in rides) {
  await logger.log("Processing ride: ${ride.id}");
}

// ✅ GOOD - Log summary
await logger.log("Processing ${rides.length} rides");
```

### 2. Don't Log Every Frame
```dart
// ❌ BAD
@override
Widget build(BuildContext context) {
  logger.log("Building widget");  // Called many times!
  return Container();
}

// ✅ GOOD
@override
void initState() {
  super.initState();
  logger.log("Widget initialized");  // Called once
}
```

### 3. Clear Old Logs
```dart
// Run occasionally to keep log file size manageable
await logger.clearLogs();
```

---

## Testing Logs

### Test 1: Verify Logging Works
```dart
void testLogging() async {
  final logger = LoggerService();
  
  // Test 1: Basic log
  await logger.log("Test message");
  
  // Test 2: Get logs
  final content = await logger.getLogsContent();
  assert(content.contains("Test message"));
  
  print("✅ Logging works!");
}

// Call in your test
testLogging();
```

### Test 2: Verify Export Works
```dart
void testExport() async {
  final logger = LoggerService();
  
  // Log something
  await logger.log("Test export");
  
  // Export
  final file = await logger.exportLogs();
  
  // Verify file exists
  assert(await file.exists());
  
  print("✅ Export works!");
}
```

---

## Complete Example Widget

```dart
import 'package:flutter/material.dart';
import 'package:hopper/Core/Services/logger_service.dart';

class RideAcceptanceButton extends StatelessWidget {
  final String rideId;
  final VoidCallback onSuccess;
  
  const RideAcceptanceButton({
    required this.rideId,
    required this.onSuccess,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () => _acceptRide(context),
      child: const Text("Accept Ride"),
    );
  }

  Future<void> _acceptRide(BuildContext context) async {
    final logger = LoggerService();
    
    try {
      // Log the action
      await logger.log("Accepting ride: $rideId");
      
      // Perform action
      // await rideService.acceptRide(rideId);
      
      // Log success
      await logger.log("Ride accepted successfully: $rideId");
      
      onSuccess();
    } catch (e, st) {
      // Log error
      await logger.logError("Failed to accept ride", e, st);
      
      // Show error to user
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to accept ride")),
        );
      }
    }
  }
}
```

---

## Quick Copy-Paste Blocks

### Add to Any Widget
```dart
import 'package:hopper/Core/Services/logger_service.dart';

// In your method:
final logger = LoggerService();
await logger.log("Your message here");
```

### Add to Error Handling
```dart
catch (e, st) {
  await LoggerService().logError("Operation failed", e, st);
}
```

### Add to API Call
```dart
// Just call API normally - logging is automatic!
final response = await dio.get('/endpoint');
```

---

That's it! Copy and paste these snippets into your code as needed. 🚀
