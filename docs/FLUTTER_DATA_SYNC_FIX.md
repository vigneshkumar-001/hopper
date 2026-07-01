# Flutter Data Sync Issue - WAITING FOR PICKUP (5) Bug Fix

## Problem Identified

**Screenshot shows**: "WAITING FOR PICKUP (5)"
**Database has**: 2 active seats
**Issue**: Flutter in-memory `riders` list is out of sync with backend database

---

## Root Cause Analysis

### Data Flow Mismatch

```
Backend (Database):
  db.driverlivetrackings.seats = [2 seats]
  db.userbookings = [Only 2 ACTIVE bookings]

Flutter App (In-Memory):
  SharedRideController.riders = [5 riders in list]
  
  ❌ MISMATCH: 5 != 2
```

### Why It Happens

```
Timeline:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

T0:00 - Driver accepts 5 bookings
  ├─ Backend DB updated: 5 seats
  ├─ Socket emits: "new-booking" × 5
  └─ Flutter receives via upsertFromSocket()
     └─ riders.add(newRider) × 5
     └─ riders.length = 5 ✓

T1:00 - 3 bookings completed/cancelled
  ├─ Backend DB: Updated activeSharedBookings to 2
  ├─ Socket should emit: "rider-removed" × 3
  │  BUT:
  │  ❌ Socket event not sent
  │  ❌ Flutter list not updated
  │  ❌ riders.length still = 5
  │
  └─ App shows: "WAITING FOR PICKUP (5)"
     But database has only 2!
```

### Code Locations

| Component | Location | Issue |
|-----------|----------|-------|
| **In-Memory Riders List** | `shared_ride_controller.dart:59` | `riders` list grows but never shrinks |
| **Socket Data Listener** | `driver_main_controller.dart:2217` | Calls `upsertFromSocket()` but no removal logic |
| **Display Logic** | `picking_shared_screens.dart:1573` | Shows `waitingRiders.length` from stale list |
| **API Sync** | `picking_customer_shared_controller.dart:353` | Only syncs on init, not continuously |

---

## Solution 1: API Fetch (RECOMMENDED) ✅

### Best: Fetch fresh data from API instead of relying on socket

**File**: `lib/Presentation/DriverScreen/screens/SharedBooking/Controller/shared_ride_controller.dart`

```dart
/// Sync riders list from API (source of truth)
Future<void> syncFromAPI(String driverId) async {
  try {
    // Fetch current driver state from backend
    final response = await ApiService.getDriverLiveTracking(driverId);
    
    if (response == null) return;
    
    final tracking = response.data['data'];
    final seats = tracking['seats'] as List? ?? [];
    
    // Clear stale riders
    riders.clear();
    
    // Rebuild from fresh API data (source of truth)
    for (final seat in seats) {
      final passengerId = seat['passengerId'];
      if (passengerId == null) continue;
      
      // Only add if not already in list
      if (riders.any((r) => r.bookingId == passengerId)) continue;
      
      riders.add(
        SharedRiderItem(
          bookingId: passengerId,
          name: seat['name'] ?? 'Passenger',
          phone: seat['phone'] ?? '',
          profilePic: seat['profilePic'] ?? '',
          pickupAddress: seat['pickupAddress'] ?? 'Unknown',
          dropoffAddress: seat['dropoffAddress'] ?? 'Unknown',
          pickupLatLng: LatLng(...),
          dropLatLng: LatLng(...),
        ),
      );
    }
    
    riders.refresh();
    
    logger.info('[SYNC] Riders synced from API', {
      'count': riders.length,
      'driverId': driverId
    });
  } catch (e) {
    logger.error('[SYNC] Failed to sync riders', {'error': e.toString()});
  }
}

/// Call this when screen loads
@override
void onInit() {
  super.onInit();
  
  // Sync immediately on init
  syncFromAPI(driverId);
  
  // Sync every 30 seconds as fallback
  Timer.periodic(Duration(seconds: 30), (_) async {
    await syncFromAPI(driverId);
  });
}
```

---

## Solution 2: Socket Event Handler (SUPPORTING)

### Also handle rider removal via socket

**File**: `lib/Presentation/DriverScreen/controller/driver_main_controller.dart`

```dart
// Add socket listener for rider removal
c.socketService.on('rider-removed', (data) {
  if (!mounted) return;
  
  final bookingId = data['bookingId'] as String?;
  if (bookingId == null) return;
  
  // Remove from Flutter list
  sharedRideController.removeRider(bookingId);
  
  logger.info('[SOCKET] Rider removed event received', {
    'bookingId': bookingId,
    'remainingRiders': sharedRideController.riders.length
  });
});

// Add socket listener for rider completion
c.socketService.on('rider-completed', (data) {
  if (!mounted) return;
  
  final bookingId = data['bookingId'] as String?;
  if (bookingId == null) return;
  
  // Mark as dropped (removed from waiting/onboard)
  sharedRideController.markDropped(bookingId);
  
  logger.info('[SOCKET] Rider completed event received', {
    'bookingId': bookingId
  });
});
```

---

## Solution 3: Manual Refresh Button (USER-FACING)

### Add "Sync Now" button for users if data looks wrong

**File**: `lib/Presentation/DriverScreen/screens/SharedBooking/Screens/picking_shared_screens.dart`

```dart
// Add refresh button in ETA row
Widget _buildRefreshButton() {
  return Obx(() {
    final syncing = c.isSyncing.value;
    
    return GestureDetector(
      onTap: syncing ? null : () => c.syncFromAPI(driverId),
      child: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: syncing ? Colors.grey : _C.green,
          shape: BoxShape.circle,
        ),
        child: Icon(
          syncing ? Icons.hourglass_empty : Icons.refresh,
          color: Colors.white,
          size: 18,
        ),
      ),
    );
  });
}

// In _buildEtaRow(), add refresh button:
Row(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    // ... existing ETA content ...
    SizedBox(width: 10),
    _buildRefreshButton(),  // ← Add this
  ],
)
```

---

## Implementation Steps

### Step 1: Update SharedRideController

**File**: `shared_ride_controller.dart`

Add these methods:

```dart
final RxBool isSyncing = false.obs;

/// Fetch riders from API (source of truth)
Future<void> syncFromAPI(String driverId) async {
  if (isSyncing.value) return;
  
  try {
    isSyncing.value = true;
    
    // TODO: Replace with your actual API call
    // final response = await ApiClient.get('/driver/$driverId/live-tracking');
    
    // Clear and rebuild
    riders.clear();
    riders.refresh();
    
  } finally {
    isSyncing.value = false;
  }
}

/// Clear all riders (for cleanup)
void clearRiders() {
  riders.clear();
  activeTarget.value = null;
  riders.refresh();
}
```

### Step 2: Call sync on screen init

**File**: `picking_customer_shared_controller.dart`

In `initState()`:

```dart
@override
void onInit() {
  super.onInit();
  
  // ✅ NEW: Sync riders from API instead of relying only on socket
  sharedRideController.syncFromAPI(driverId);
  
  // ✅ Also setup periodic sync
  _syncTimer = Timer.periodic(Duration(seconds: 30), (_) {
    sharedRideController.syncFromAPI(driverId);
  });
}

@override
void onClose() {
  _syncTimer?.cancel();
  super.onClose();
}
```

### Step 3: Update display logic

**File**: `picking_shared_screens.dart` (already correct, just verify)

Line 1573 displays:
```dart
'WAITING FOR PICKUP (${waitingRiders.length})'
```

This is correct! It shows the actual in-memory count. Once we sync from API, it will show the correct number.

---

## Testing

### Test 1: Verify API sync works

```dart
// Call this to trigger sync
await sharedRideController.syncFromAPI(driverId);

// Verify riders count matches backend
final backendCount = 2; // from screenshot
final flutterCount = sharedRideController.riders.length;

assert(flutterCount == backendCount, 'Mismatch!');
```

### Test 2: Verify socket updates work

1. Open the app (riders = 2)
2. Backend completes 1 rider
3. Socket sends rider-removed event
4. Flutter count should become 1
5. Display should update to "WAITING FOR PICKUP (1)"

### Test 3: Restart app

1. Backend has 2 active riders
2. Close and restart app
3. App syncs from API on init
4. Display should show "WAITING FOR PICKUP (2)" (correct!)

---

## Logging to Add

### In syncFromAPI:

```dart
logger.info('[RIDERS-SYNC] Synced from API', {
  'driverId': driverId,
  'count': riders.length,
  'timestamp': DateTime.now().toIso8601String()
});
```

### In upsertFromSocket:

```dart
logger.info('[RIDERS-SOCKET] Rider added/updated', {
  'bookingId': bookingIdStr,
  'totalRiders': riders.length,
  'source': 'socket'
});
```

### In removeRider:

```dart
logger.info('[RIDERS-REMOVE] Rider removed', {
  'bookingId': bookingId,
  'remainingRiders': riders.length,
  'source': 'socket'
});
```

---

## Why This Fix Works

✅ **API is source of truth** - Backend `seats` array is the actual state
✅ **Periodic sync** - Every 30 seconds, riders list refreshes from API
✅ **Socket still works** - Real-time updates via socket for performance
✅ **Fallback mechanism** - If socket fails, periodic sync catches it
✅ **User can manually refresh** - "Sync Now" button for immediate updates
✅ **No data loss** - Only removes riders from UI if they're gone from backend

---

## Files to Modify

1. ✅ `shared_ride_controller.dart` - Add `syncFromAPI()` method
2. ✅ `picking_customer_shared_controller.dart` - Call sync on init
3. ✅ `driver_main_controller.dart` - Add socket handlers for removal
4. ✅ `picking_shared_screens.dart` - Add refresh button (optional)

---

## Current Status

❌ **Issue**: Shows 5 riders, database has 2
✅ **Root Cause**: In-memory list not synced with backend
✅ **Fix**: Fetch from API instead of relying on stale socket data

**Implementation**: ~2 hours
**Testing**: ~1 hour
**Risk**: Low (only changes how data is loaded)

---

## Next Steps

1. Implement `syncFromAPI()` in SharedRideController
2. Add periodic timer in screen init
3. Add socket handlers for rider removal
4. Test with mixed rider states (some completed, some waiting)
5. Monitor logs to verify sync is working
6. Deploy with confidence!

---

## API Response Format Expected

```json
{
  "status": 200,
  "data": {
    "driverId": "...",
    "seats": [
      {
        "seatNumber": 2,
        "passengerId": "BOOKING-001",
        "customerId": "...",
        "name": "John Doe",
        "phone": "+91...",
        "profilePic": "https://...",
        "pickupAddress": "...",
        "dropoffAddress": "..."
      },
      {
        "seatNumber": 3,
        "passengerId": "BOOKING-002",
        ...
      }
    ],
    "occupiedSeats": 2
  }
}
```

This way, Flutter always knows the truth from the backend!
