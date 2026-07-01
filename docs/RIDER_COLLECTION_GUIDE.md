# 🚗 Why Multiple Riders Aren't Being Collected - Debugging Guide

## Quick Answer
Your app shows 2 riders but stops receiving more. This is likely due to:
1. **Socket connection dropping** after initial riders
2. **No retry logic** for failed rider upserts
3. **Riders clearing** when socket reconnects
4. **Backend not sending** additional share-ride-request events

---

## Step 1: Check Socket Connection

### Open Log Viewer
1. Add a debug button to your main screen:
```dart
floatingActionButton: FloatingActionButton(
  child: const Icon(Icons.description),
  onPressed: () => Get.to(() => const LogViewerScreen()),
),
```

2. **Filter by "Socket" type** in Log Viewer
3. Look for:
   - ✅ `SOCKET_CONNECTED` events
   - ❌ `SOCKET_DISCONNECTED` events (with reason)
   - ⚠️ `SOCKET_ERROR` events

### Example Log Analysis:
```
[11:40:00] SOCKET_CONNECTED
[11:40:05] SOCKET_EVENT: share-ride-request (fenizo User)
[11:40:08] SOCKET_EVENT: share-ride-request (satz User)
[11:41:10] SOCKET_DISCONNECTED: Connection timeout
[11:41:15] SOCKET_RECONNECTING
[11:41:20] SOCKET_CONNECTED
```

**Result**: Socket disconnected after 2 riders! No new riders after reconnect.

---

## Step 2: Check Rider Events

### Filter by "Rider" type in Log Viewer
```
[11:40:05] RIDER_ADDED (Booking: b001) - fenizo User
[11:40:08] RIDER_ADDED (Booking: b002) - satz User
[11:41:10] ❌ NO MORE RIDER_ADDED EVENTS
```

### Questions to ask:
- **How many RIDER_ADDED events?** (Should match your expectation)
- **When do they stop?** (Is it after a time, after a socket error, etc.)
- **Any RIDER_UPDATED events?** (Old riders being updated instead of new ones added)

---

## Step 3: Check API Calls

### Filter by "API" type in Log Viewer
Look for any failed calls:
```
[11:40:00] GET /api/shared-bookings (Status: 200) ✅
[11:40:05] GET /api/riders (Status: 200) ✅
[11:41:15] GET /api/riders (Status: 500) ❌ Internal server error
```

### Common API Issues:
- **401/403** → Authentication expired
- **500** → Backend error
- **Timeout** → Network issue

---

## Step 4: Enable Advanced Socket Logging

### Add detailed logging to picking_customer_shared_controller.dart

```dart
// In the initialization section (line 520):

socketService.socket.onAny((event, data) {
  // Log ALL socket events with full details
  logManager.logSocket(
    event: event,
    data: data,
    error: null, // Will only log if there's an error
  );
  
  CommonLogger.log.i('📦 [shared picking socket] $event: $data');
});

// Specifically track rider events:
socketService.on('share-ride-request', (data) {
  logManager.logSocket(
    event: 'SHARE_RIDE_REQUEST_RECEIVED',
    data: {
      'bookingId': data['bookingId'],
      'customerName': data['customerName'],
      'currentRiderCount': sharedRideController.riders.length + 1,
    },
  );
  
  // Then process it
  await sharedRideController.upsertFromSocket(data);
  
  logManager.logSocket(
    event: 'SHARE_RIDE_REQUEST_PROCESSED',
    data: {
      'bookingId': data['bookingId'],
      'totalRidersNow': sharedRideController.riders.length,
    },
  );
});

// Track when socket disconnects
socketService.onDisconnect(() {
  socketMonitor.onDisconnect(
    'Disconnected from server',
    riderCount: sharedRideController.riders.length,
  );
});

// Track errors
socketService.onError((err) {
  socketMonitor.onError(err.toString());
  logManager.logSocket(
    event: 'SOCKET_ERROR',
    data: {'error': err.toString()},
    error: err.toString(),
  );
});
```

---

## Step 5: Real-time Monitoring Dashboard

### Add a status widget to your UI:
```dart
Obx(() {
  final status = socketMonitor.getStatus();
  return Container(
    padding: EdgeInsets.all(12),
    color: status['isConnected'] ? Colors.green : Colors.red,
    child: Text(
      'Socket: ${status['isConnected'] ? '✅ Connected' : '❌ Disconnected'} | '
      'Riders: ${sharedRideController.riders.length} | '
      'Disconnections: ${status['disconnectionCount']}',
      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
    ),
  );
}),
```

---

## Step 6: Common Scenarios & Solutions

### Scenario A: Socket disconnects after 2 riders
**Symptoms**:
- Socket connects ✅
- 2 riders added ✅
- Socket disconnects ❌
- No more riders after reconnect

**Solutions**:
```dart
// 1. Increase socket timeout
socketService.setReconnectDelay(Duration(seconds: 3));

// 2. Implement auto-reconnect with rider retry
socketService.onReconnect(() {
  // Refetch riders after reconnect
  await _refetchRidersFromBackend();
});

// 3. Persist riders in local database
// Even if socket disconnects, riders remain visible
```

### Scenario B: Riders added but stuck at same count
**Symptoms**:
- 2 riders added ✅
- New riders arrive but UI doesn't update ✅ (in logs)
- But screen still shows 2

**Solutions**:
```dart
// Force refresh UI after each upsert
sharedRideController.riders.refresh();

// Or use a stream listener instead of just socket
// Better for real-time updates
```

### Scenario C: Socket receives events but riders not added
**Symptoms**:
- Socket events in logs ✅
- But RIDER_ADDED events missing ❌
- Riders count stays at 2

**Solutions**:
```dart
// Check if upsertFromSocket has errors:
try {
  await sharedRideController.upsertFromSocket(data);
} catch (e) {
  logManager.logError(
    'Failed to upsert rider',
    bookingId: data['bookingId'],
    stackTrace: e,
  );
}
```

---

## Step 7: Comprehensive Debugging Workflow

### 1. **Reproduce the issue**
   - Open app
   - Start shared ride
   - Wait for riders to arrive
   - Note when it stops

### 2. **Export logs while issue is happening**
   - Don't close the app
   - Go to Log Viewer
   - Filter by "Socket" type
   - Export as JSON
   - Check the timeline

### 3. **Analyze the timeline**
   ```
   Time    | Event                           | Riders | Status
   ------- | ------------------------------- | ------ | ------
   11:40   | SOCKET_CONNECTED                | 0      | ✅
   11:40   | SHARE_RIDE_REQUEST_RECEIVED     | 0      | ✅
   11:40   | RIDER_ADDED (fenizo)            | 1      | ✅
   11:40   | SHARE_RIDE_REQUEST_RECEIVED     | 1      | ✅
   11:40   | RIDER_ADDED (satz)              | 2      | ✅
   11:41   | SOCKET_DISCONNECTED             | 2      | ❌ ISSUE
   11:41   | SOCKET_RECONNECTING             | 2      | 🔄
   11:41   | SOCKET_CONNECTED                | 2      | ✅
   13:00   | (No new events)                 | 2      | ❌ Stuck
   ```

### 4. **Identify the pattern**
   - Are disconnections regular? (Every N minutes)
   - Do new riders come and then disconnect? (App issue)
   - Or no new riders ever arrive? (Backend issue)

### 5. **Report findings**
   ```markdown
   **Issue**: Riders stuck at 2
   
   **Timeline**:
   - Socket connects at 11:40
   - 2 riders added by 11:40
   - Socket disconnects at 11:41 (reason: Connection timeout)
   - Socket reconnects but no new rider events received
   
   **Hypothesis**: Backend stops sending share-ride-request events after initial 2
   
   **Action**: Check backend logs for why no new riders are being queued
   ```

---

## Step 8: Quick Checklist

- [ ] Socket connection status in Log Viewer
- [ ] Socket disconnect count and reasons
- [ ] Rider events in exact order (added, updated, dropped)
- [ ] API call errors (401, 500, timeout)
- [ ] Timeline of when riders stopped being added
- [ ] Export logs before/after issue
- [ ] Check Device → Logcat for native errors
- [ ] Verify network connectivity
- [ ] Check if issue is consistent or intermittent
- [ ] Compare behavior on different devices

---

## Step 9: Sharing Logs with Backend Team

### Export and send logs:
```dart
// In Log Viewer, tap Export → JSON
// File saved to: /Documents/hopper_logs/hopper_logs_2026-06-23_11-41.json

// Send to backend team with:
1. Your device info
2. Time the issue occurred
3. Your account booking ID
4. Expected vs actual rider count
```

### What backend team will look for:
```json
{
  "timestamp": "2026-06-23T11:40:05.000Z",
  "type": "socket",
  "event": "SHARE_RIDE_REQUEST_RECEIVED",
  "data": {
    "bookingId": "booking_b001",
    "customerName": "fenizo User"
  }
}
```

---

## Step 10: Prevention

### Add these safeguards:
```dart
// 1. Auto-refresh riders every 30 seconds
Timer.periodic(Duration(seconds: 30), (_) {
  _refetchRidersFromBackend();
});

// 2. Monitor socket health
Timer.periodic(Duration(seconds: 5), (_) {
  if (!socketMonitor.isConnected.value) {
    logManager.logError('Socket disconnected, attempting reconnect');
    socketService.reconnect();
  }
});

// 3. Clear and refetch on error
socketService.onError((err) {
  logManager.logError('Socket error, clearing riders to refetch', error: err);
  sharedRideController.riders.clear();
  _refetchRidersFromBackend();
});
```

---

**Still stuck? Attach Log Viewer export when asking for help! 📊📤**
