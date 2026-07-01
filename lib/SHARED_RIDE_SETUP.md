# 🚀 Shared Ride Feature - Setup & Integration Guide

## Overview
This guide explains how to integrate and use the Shared Ride feature in the Hopper Driver app.

### Components Created
- ✅ **SharedRideSocketService** - Real-time socket communication for shared rides
- ✅ **SharedRideDataSource** - HTTP API endpoints for shared ride operations
- ✅ **SharedRideRepository** - Unified interface combining both data sources
- ✅ **Backend Routes** - Registered in modules/index.ts

---

## 1️⃣ GetX Initialization (main.dart or bindings.dart)

### Option A: Using GetX Services

In your `main.dart` or a dedicated `bindings.dart` file:

```dart
import 'package:hopper/Core/Services/shared_ride_socket_service.dart';
import 'package:hopper/api/repository/shared_ride_repository.dart';

// Add to GetX initialization (usually in Bindings or main.dart)
Future<void> initializeSharedRide() async {
  // Initialize SharedRideSocketService as a GetX service
  await Get.putAsync<SharedRideSocketService>(
    () async => SharedRideSocketService(),
  );

  // Initialize repository (will find socket service via Get.find())
  Get.lazyPut<SharedRideRepository>(
    () => SharedRideRepository(
      dataSource: SharedRideDataSource(Get.find()), // ApiClient
      socketService: Get.find<SharedRideSocketService>(),
    ),
  );
}
```

### Option B: Auto-Wiring Pattern

```dart
class SharedRideBinding extends Bindings {
  @override
  void dependencies() {
    Get.putAsync<SharedRideSocketService>(
      () async => SharedRideSocketService(),
    );

    Get.lazyPut<SharedRideRepository>(
      () => SharedRideRepository.instance(),
    );
  }
}

// In your route/page:
GetPage(
  name: '/shared-ride',
  page: () => SharedRidePage(),
  binding: SharedRideBinding(),
)
```

---

## 2️⃣ Using the Repository in Your Controller

```dart
import 'package:get/get.dart';
import 'package:hopper/api/repository/shared_ride_repository.dart';

class SharedRideController extends GetxController {
  late SharedRideRepository _repository;

  @override
  void onInit() {
    super.onInit();
    _repository = Get.find<SharedRideRepository>();
    
    // Connect socket when user logs in
    _connectSocket();
    
    // Listen to ride events
    _listenToRideEvents();
  }

  void _connectSocket() {
    final driverId = "current_driver_id"; // Get from auth
    final authToken = "auth_token"; // Get from auth
    _repository.connectSocket(driverId, authToken);
  }

  void _listenToRideEvents() {
    _repository.rideEventStream.listen((event) {
      print('🔔 Ride Event: ${event['event']}');
      // Handle different event types
      switch (event['event']) {
        case 'ride_match_found':
          _handleMatchFound(event['data']);
          break;
        case 'ride_matched':
          _handleRideMatched(event['data']);
          break;
        case 'driver_location_update':
          _handleLocationUpdate(event['data']);
          break;
        // ... handle other events
      }
    });

    _repository.errorStream.listen((error) {
      print('❌ Socket Error: $error');
      // Handle socket errors
    });
  }

  // Request a shared ride
  Future<void> requestSharedRide({
    required double pickupLat,
    required double pickupLng,
    required double dropLat,
    required double dropLng,
    required int passengerCount,
  }) async {
    try {
      final result = await _repository.requestSharedRide(
        pickupLatitude: pickupLat,
        pickupLongitude: pickupLng,
        dropLatitude: dropLat,
        dropLongitude: dropLng,
        passengerCount: passengerCount,
      );
      
      print('✅ Ride requested: ${result['rideId']}');
    } catch (e) {
      print('❌ Error: $e');
    }
  }

  // Accept a shared ride match
  Future<void> acceptMatch(String matchId, String rideId) async {
    try {
      await _repository.confirmSharedRideMatch(
        matchId: matchId,
        rideId: rideId,
      );
      print('✅ Match confirmed');
    } catch (e) {
      print('❌ Error: $e');
    }
  }

  // Verify pickup OTP
  Future<void> verifyOTP(String otp) async {
    try {
      await _repository.verifyPickupOTP(otp);
      print('✅ OTP verified');
    } catch (e) {
      print('❌ Error: $e');
    }
  }

  @override
  void onClose() {
    _repository.disconnectSocket();
    super.onClose();
  }
}
```

---

## 3️⃣ Using in UI Widgets

### Example: Display Available Matches

```dart
class SharedRideMatchListWidget extends GetWidget<SharedRideController> {
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final matches = controller._repository.availableMatches;
      
      if (matches.isEmpty) {
        return Center(child: Text('No matches available'));
      }

      return ListView.builder(
        itemCount: matches.length,
        itemBuilder: (context, index) {
          final match = matches[index];
          return Card(
            child: ListTile(
              title: Text('Match ${index + 1}'),
              subtitle: Text('Fare: \$${match['fare']}'),
              onTap: () => controller.acceptMatch(
                match['matchId'],
                match['rideId'],
              ),
            ),
          );
        },
      );
    });
  }
}
```

### Example: Real-Time Location Display

```dart
class DriverLocationWidget extends GetWidget<SharedRideController> {
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final location = controller._repository.driverLocation.value;
      final fare = controller._repository.totalFare.value;
      final eta = controller._repository.estimatedArrival.value;

      return Container(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Location: ${location['lat']}, ${location['lng']}'),
            Text('Fare: \$${fare.toStringAsFixed(2)}'),
            Text('ETA: $eta minutes'),
          ],
        ),
      );
    });
  }
}
```

### Example: Monitor Ride Status

```dart
class RideStatusWidget extends GetWidget<SharedRideController> {
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final status = controller._repository.rideStatus.value;
      final color = _getStatusColor(status);

      return Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Status: ${status.toUpperCase()}',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      );
    });
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'waiting':
        return Colors.grey;
      case 'matched':
        return Colors.blue;
      case 'pickup':
        return Colors.orange;
      case 'in_progress':
        return Colors.purple;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
```

---

## 4️⃣ Backend Configuration

### Socket.IO Server Setup (Backend)

Update your backend Socket.IO configuration to handle shared ride events:

```typescript
// Example: socket.service.ts
export class SocketService {
  handleSharedRideEvents(socket: Socket) {
    // Listen for shared ride events
    socket.on('request_shared_ride', (data) => {
      // Match and emit suitable rides
      socket.emit('ride_match_found', matches);
    });

    socket.on('confirm_ride_match', (data) => {
      // Process confirmation
      socket.emit('ride_matched_confirmed', rideDetails);
    });

    socket.on('update_driver_location', (data) => {
      // Broadcast location to relevant passengers
      socket.emit('driver_location_update', data);
    });

    // ... handle other events
  }
}
```

### Base URL Configuration

Update the base URL in `SharedRideSocketService`:

```dart
// In shared_ride_socket_service.dart
final String _baseUrl = 'http://your-backend-url.com'; // Update this
```

---

## 5️⃣ Available Observable Properties

All these are reactive (Obx-compatible):

```dart
// Current ride
_repository.currentRideId         // Rx<String?>
_repository.rideStatus            // RxString
_repository.totalFare             // RxDouble
_repository.estimatedArrival      // RxInt

// Locations
_repository.driverLocation        // Rx<Map<String, double>>
_repository.availableMatches      // RxList<Map>

// Connection
_repository.isSocketConnected     // RxBool
```

---

## 6️⃣ Stream Subscriptions

For advanced use cases, listen to streams:

```dart
// Listen to all ride events
_repository.rideEventStream.listen((event) {
  print('Event: ${event['event']}');
  print('Data: ${event['data']}');
  print('Timestamp: ${event['timestamp']}');
});

// Listen to socket errors
_repository.errorStream.listen((error) {
  print('Socket Error: $error');
  // Show error dialog or snackbar
});
```

---

## 7️⃣ Common Use Cases

### Case 1: Request → Match → Accept → Complete

```dart
// 1. Request ride
await _repository.requestSharedRide(
  pickupLatitude: 40.7128,
  pickupLongitude: -74.0060,
  dropLatitude: 40.7580,
  dropLongitude: -73.9855,
  passengerCount: 2,
);

// 2. Listen for matches (via rideEventStream)
// 3. Accept match when found
await _repository.confirmSharedRideMatch(
  matchId: matchData['matchId'],
  rideId: matchData['rideId'],
);

// 4. Real-time location updates
_repository.updateDriverLocation(
  latitude: currentLat,
  longitude: currentLng,
);

// 5. Complete ride
await _repository.completeSharedRide(
  finalLatitude: 40.7580,
  finalLongitude: -73.9855,
  finalFare: 25.50,
);
```

### Case 2: Driver Analytics

```dart
// Get shared ride history
final history = await _repository.getDriverSharedRideHistory(
  driverId: 'driver_123',
  limit: 10,
);

// Get analytics
final analytics = await _repository.getSharedRideAnalytics(
  driverId: 'driver_123',
  period: 'week', // 'today', 'week', 'month', 'all'
);

print('Total earnings: \$${analytics['totalEarnings']}');
print('Rides completed: ${analytics['completedRides']}');
```

---

## 8️⃣ Error Handling

```dart
try {
  await _repository.requestSharedRide(...);
} on SocketException catch (e) {
  print('Socket error: ${e.message}');
  // Reconnect or show offline message
} on TimeoutException catch (e) {
  print('Request timeout');
  // Retry logic
} catch (e) {
  print('Unknown error: $e');
}
```

---

## 9️⃣ Logging

All socket events are automatically logged via `logManager`:

- Event type
- Timestamp
- Relevant data
- Errors (if any)

View logs in the app's logging system or export via the UI.

---

## 🔟 Socket Events Summary

### Listen Events (Server → Client)
- `ride_match_found` - New matches available
- `ride_matched_confirmed` - Match confirmed
- `driver_location_update` - Driver's location
- `passenger_location_update` - Passenger locations
- `pickup_otp_generated` - Pickup OTP
- `ride_status_changed` - Status updates
- `fare_calculated` - Fare breakdown
- `eta_updated` - ETA changes
- `ride_completed` - Ride finished
- `ride_cancelled` - Ride cancelled
- `driver_assigned` - Driver assigned
- `capacity_warning` - Vehicle at capacity

### Emit Events (Client → Server)
- `request_shared_ride` - Request a ride
- `confirm_ride_match` - Confirm a match
- `update_driver_location` - Send location
- `verify_pickup_otp` - Verify OTP
- `complete_shared_ride` - Mark ride complete
- `cancel_shared_ride` - Cancel ride

---

## 🔧 Troubleshooting

### Socket Not Connecting?
1. Check backend URL is correct
2. Verify auth token is valid
3. Check network connectivity
4. Look at logs: `logManager.logSocket(...)`

### Events Not Received?
1. Ensure socket is connected: `_repository.isSocketConnected.value`
2. Check event names match exactly
3. Verify server is emitting events
4. Check firewall/proxy settings

### Location Updates Failing?
1. Verify location permissions
2. Check ride is active: `_repository.currentRideId.value != null`
3. Ensure location updates are frequent enough
4. Check network connectivity

---

## 📚 Additional Resources

- Backend API: `hoppr-single-ride/src/modules/SharedRide/`
- Socket Service: `lib/Core/Services/shared_ride_socket_service.dart`
- Repository: `lib/api/repository/shared_ride_repository.dart`
- Data Source: `lib/api/dataSource/shared_ride_datasource.dart`

---

**Created:** 2026-06-25  
**Status:** ✅ Ready for Integration  
**Next Steps:** Wire up in your controllers and UI screens!
