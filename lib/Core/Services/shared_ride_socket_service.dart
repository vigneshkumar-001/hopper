import 'package:get/get.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:hopper/Core/Services/log_manager.dart';
import 'package:hopper/Core/Services/socket_monitor.dart';
import 'dart:async';

/// Real-time socket service for shared ride functionality
/// Handles: ride matching, driver location updates, pickup OTP, ride completion
class SharedRideSocketService extends GetxService {
  static SharedRideSocketService get to => Get.find();

  late IO.Socket socket;
  final String _baseUrl = 'http://localhost:3000'; // Update with your backend URL

  // ─── Observables ───────────────────────────────────────────────────────────

  /// Current shared ride ID being tracked
  final Rx<String?> currentRideId = Rx(null);

  /// Available shared ride matches
  final RxList<Map<String, dynamic>> availableMatches = <Map<String, dynamic>>[].obs;

  /// Current driver location in shared ride
  final Rx<Map<String, double>> driverLocation = Rx({'lat': 0.0, 'lng': 0.0});

  /// Passenger locations in shared ride
  final RxList<Map<String, dynamic>> passengerLocations =
      <Map<String, dynamic>>[].obs;

  /// Pickup OTP for current ride
  final Rx<String?> pickupOTP = Rx(null);

  /// Ride status (waiting, matched, pickup, in_progress, completed, cancelled)
  final RxString rideStatus = 'waiting'.obs;

  /// Total fare for shared ride
  final RxDouble totalFare = 0.0.obs;

  /// Estimated arrival time in minutes
  final RxInt estimatedArrival = 0.obs;

  /// Shared ride details
  final Rx<Map<String, dynamic>> rideDetails = Rx({});

  /// Connection status
  final RxBool isConnected = false.obs;

  /// StreamControllers for events
  late StreamController<Map<String, dynamic>> _rideEventController;
  late StreamController<String> _errorController;

  @override
  void onInit() {
    super.onInit();
    _rideEventController = StreamController.broadcast();
    _errorController = StreamController.broadcast();
    _initializeSocket();
  }

  // ─── Socket Initialization ─────────────────────────────────────────────────

  void _initializeSocket() {
    socket = IO.io(
      _baseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setReconnectionDelay(2000)
          .setReconnectionDelayMax(10000)
          .setReconnectionAttempts(10)
          .build(),
    );

    _setupSocketListeners();

    logManager.logSocket(
      event: 'SOCKET_INITIALIZED',
      data: {'baseUrl': _baseUrl, 'timestamp': DateTime.now().toIso8601String()},
    );
  }

  // ─── Socket Connection Management ──────────────────────────────────────────

  /// Connect to shared ride socket server
  void connect(String driverId, String authToken) {
    if (socket.connected) return;

    socket.auth = {'authorization': authToken};
    socket.connect();

    logManager.logSocket(
      event: 'SOCKET_CONNECT_INITIATED',
      data: {
        'driverId': driverId,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Disconnect from socket server
  void disconnect() {
    if (socket.connected) {
      socket.disconnect();
    }
    currentRideId.value = null;
    rideStatus.value = 'waiting';
    logManager.logSocket(
      event: 'SOCKET_DISCONNECTED',
      data: {'timestamp': DateTime.now().toIso8601String()},
    );
  }

  // ─── Socket Event Listeners ────────────────────────────────────────────────

  void _setupSocketListeners() {
    // Connection events
    socket.on('connect', (_) {
      isConnected.value = true;
      socketMonitor.onConnect();
      logManager.logSocket(
        event: 'SHARED_RIDE_SOCKET_CONNECTED',
        data: {'socketId': socket.id, 'timestamp': DateTime.now().toIso8601String()},
      );
    });

    socket.on('disconnect', (reason) {
      isConnected.value = false;
      socketMonitor.onDisconnect(reason.toString());
      logManager.logSocket(
        event: 'SHARED_RIDE_SOCKET_DISCONNECTED',
        data: {'reason': reason, 'timestamp': DateTime.now().toIso8601String()},
      );
    });

    socket.on('error', (error) {
      socketMonitor.onError(error.toString());
      _errorController.add(error.toString());
      logManager.logSocket(
        event: 'SHARED_RIDE_SOCKET_ERROR',
        data: {'error': error, 'timestamp': DateTime.now().toIso8601String()},
        error: error.toString(),
      );
    });

    // Shared Ride Events
    socket.on('ride_match_found', _onRideMatchFound);
    socket.on('ride_matched_confirmed', _onRideMatched);
    socket.on('driver_location_update', _onDriverLocationUpdate);
    socket.on('passenger_location_update', _onPassengerLocationUpdate);
    socket.on('pickup_otp_generated', _onPickupOTPGenerated);
    socket.on('ride_status_changed', _onRideStatusChanged);
    socket.on('fare_calculated', _onFareCalculated);
    socket.on('eta_updated', _onETAUpdated);
    socket.on('ride_completed', _onRideCompleted);
    socket.on('ride_cancelled', _onRideCancelled);
    socket.on('driver_assigned', _onDriverAssigned);
    socket.on('capacity_warning', _onCapacityWarning);
  }

  // ─── Event Handlers ────────────────────────────────────────────────────────

  void _onRideMatchFound(dynamic data) {
    try {
      availableMatches.add(Map<String, dynamic>.from(data));
      rideStatus.value = 'match_available';

      logManager.logSocket(
        event: 'RIDE_MATCH_FOUND',
        data: {
          'matchCount': availableMatches.length,
          'matchDetails': data,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      _rideEventController.add({
        'event': 'ride_match_found',
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      _handleEventError('ride_match_found', e);
    }
  }

  void _onRideMatched(dynamic data) {
    try {
      currentRideId.value = data['rideId'];
      rideStatus.value = 'matched';
      rideDetails.value = Map<String, dynamic>.from(data);

      logManager.logSocket(
        event: 'RIDE_MATCHED_CONFIRMED',
        data: {
          'rideId': currentRideId.value,
          'passengerCount': data['passengerCount'] ?? 0,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      _rideEventController.add({
        'event': 'ride_matched',
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      _handleEventError('ride_matched_confirmed', e);
    }
  }

  void _onDriverLocationUpdate(dynamic data) {
    try {
      driverLocation.value = {
        'lat': (data['latitude'] ?? 0.0).toDouble(),
        'lng': (data['longitude'] ?? 0.0).toDouble(),
      };

      logManager.logSocket(
        event: 'DRIVER_LOCATION_UPDATED',
        data: {
          'rideId': currentRideId.value,
          'location': driverLocation.value,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      _rideEventController.add({
        'event': 'driver_location_update',
        'data': driverLocation.value,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      _handleEventError('driver_location_update', e);
    }
  }

  void _onPassengerLocationUpdate(dynamic data) {
    try {
      passengerLocations.clear();
      if (data is List) {
        passengerLocations.addAll(data.cast<Map<String, dynamic>>());
      } else if (data is Map) {
        passengerLocations.add(Map<String, dynamic>.from(data));
      }

      logManager.logSocket(
        event: 'PASSENGER_LOCATION_UPDATED',
        data: {
          'rideId': currentRideId.value,
          'passengerCount': passengerLocations.length,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      _rideEventController.add({
        'event': 'passenger_location_update',
        'data': passengerLocations,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      _handleEventError('passenger_location_update', e);
    }
  }

  void _onPickupOTPGenerated(dynamic data) {
    try {
      pickupOTP.value = data['otp'];

      logManager.logSocket(
        event: 'PICKUP_OTP_GENERATED',
        data: {
          'rideId': currentRideId.value,
          'otpLength': data['otp']?.toString().length ?? 0,
          'expiresIn': data['expiresIn'] ?? 300,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      _rideEventController.add({
        'event': 'pickup_otp_generated',
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      _handleEventError('pickup_otp_generated', e);
    }
  }

  void _onRideStatusChanged(dynamic data) {
    try {
      rideStatus.value = data['status'] ?? 'unknown';

      logManager.logSocket(
        event: 'RIDE_STATUS_CHANGED',
        data: {
          'rideId': currentRideId.value,
          'newStatus': rideStatus.value,
          'previousStatus': data['previousStatus'],
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      _rideEventController.add({
        'event': 'ride_status_changed',
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      _handleEventError('ride_status_changed', e);
    }
  }

  void _onFareCalculated(dynamic data) {
    try {
      totalFare.value = (data['totalFare'] ?? 0.0).toDouble();

      logManager.logSocket(
        event: 'FARE_CALCULATED',
        data: {
          'rideId': currentRideId.value,
          'fare': totalFare.value,
          'baseFare': data['baseFare'],
          'distanceFare': data['distanceFare'],
          'surgeMultiplier': data['surgeMultiplier'],
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      _rideEventController.add({
        'event': 'fare_calculated',
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      _handleEventError('fare_calculated', e);
    }
  }

  void _onETAUpdated(dynamic data) {
    try {
      estimatedArrival.value = (data['eta'] ?? 0).toInt();

      logManager.logSocket(
        event: 'ETA_UPDATED',
        data: {
          'rideId': currentRideId.value,
          'etaMinutes': estimatedArrival.value,
          'distance': data['distance'],
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      _rideEventController.add({
        'event': 'eta_updated',
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      _handleEventError('eta_updated', e);
    }
  }

  void _onRideCompleted(dynamic data) {
    try {
      rideStatus.value = 'completed';

      logManager.logSocket(
        event: 'RIDE_COMPLETED',
        data: {
          'rideId': currentRideId.value,
          'finalFare': data['finalFare'],
          'duration': data['duration'],
          'distance': data['distance'],
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      _rideEventController.add({
        'event': 'ride_completed',
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
      });

      Future.delayed(Duration(seconds: 2), () {
        currentRideId.value = null;
        availableMatches.clear();
      });
    } catch (e) {
      _handleEventError('ride_completed', e);
    }
  }

  void _onRideCancelled(dynamic data) {
    try {
      rideStatus.value = 'cancelled';

      logManager.logSocket(
        event: 'RIDE_CANCELLED',
        data: {
          'rideId': currentRideId.value,
          'cancellationReason': data['reason'],
          'cancelledBy': data['cancelledBy'],
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      _rideEventController.add({
        'event': 'ride_cancelled',
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
      });

      Future.delayed(Duration(seconds: 1), () {
        currentRideId.value = null;
        availableMatches.clear();
      });
    } catch (e) {
      _handleEventError('ride_cancelled', e);
    }
  }

  void _onDriverAssigned(dynamic data) {
    try {
      logManager.logSocket(
        event: 'DRIVER_ASSIGNED',
        data: {
          'rideId': currentRideId.value,
          'driverId': data['driverId'],
          'driverName': data['driverName'],
          'rating': data['rating'],
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      _rideEventController.add({
        'event': 'driver_assigned',
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      _handleEventError('driver_assigned', e);
    }
  }

  void _onCapacityWarning(dynamic data) {
    try {
      logManager.logSocket(
        event: 'CAPACITY_WARNING',
        data: {
          'rideId': currentRideId.value,
          'currentPassengers': data['currentPassengers'],
          'capacity': data['capacity'],
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      _rideEventController.add({
        'event': 'capacity_warning',
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      _handleEventError('capacity_warning', e);
    }
  }

  // ─── Emission Methods (Send Events) ────────────────────────────────────────

  /// Request a shared ride
  void requestSharedRide(Map<String, dynamic> rideRequest) {
    if (!isConnected.value) {
      _errorController.add('Socket not connected');
      return;
    }

    socket.emit('request_shared_ride', rideRequest);
    logManager.logSocket(
      event: 'REQUEST_SHARED_RIDE_SENT',
      data: {
        'pickupLocation': rideRequest['pickupLocation'],
        'dropLocation': rideRequest['dropLocation'],
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Confirm shared ride match
  void confirmRideMatch(String matchId) {
    if (!isConnected.value) {
      _errorController.add('Socket not connected');
      return;
    }

    socket.emit('confirm_ride_match', {'matchId': matchId});
    logManager.logSocket(
      event: 'CONFIRM_RIDE_MATCH_SENT',
      data: {
        'matchId': matchId,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Update driver location in real-time
  void updateDriverLocation(double latitude, double longitude) {
    if (!isConnected.value || currentRideId.value == null) return;

    socket.emit('update_driver_location', {
      'rideId': currentRideId.value,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Verify pickup OTP
  void verifyPickupOTP(String otp) {
    if (!isConnected.value || currentRideId.value == null) {
      _errorController.add('Socket not connected or no active ride');
      return;
    }

    socket.emit('verify_pickup_otp', {
      'rideId': currentRideId.value,
      'otp': otp,
    });
    logManager.logSocket(
      event: 'VERIFY_PICKUP_OTP_SENT',
      data: {
        'rideId': currentRideId.value,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Complete shared ride
  void completeSharedRide(Map<String, dynamic> completionData) {
    if (!isConnected.value || currentRideId.value == null) {
      _errorController.add('Socket not connected or no active ride');
      return;
    }

    socket.emit('complete_shared_ride', {
      'rideId': currentRideId.value,
      ...completionData,
    });
    logManager.logSocket(
      event: 'COMPLETE_SHARED_RIDE_SENT',
      data: {
        'rideId': currentRideId.value,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Cancel shared ride
  void cancelSharedRide(String reason) {
    if (!isConnected.value || currentRideId.value == null) {
      _errorController.add('Socket not connected or no active ride');
      return;
    }

    socket.emit('cancel_shared_ride', {
      'rideId': currentRideId.value,
      'reason': reason,
    });
    logManager.logSocket(
      event: 'CANCEL_SHARED_RIDE_SENT',
      data: {
        'rideId': currentRideId.value,
        'reason': reason,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  // ─── Stream Getters ────────────────────────────────────────────────────────

  /// Stream of ride events
  Stream<Map<String, dynamic>> get rideEventStream => _rideEventController.stream;

  /// Stream of socket errors
  Stream<String> get errorStream => _errorController.stream;

  // ─── Utility Methods ───────────────────────────────────────────────────────

  void _handleEventError(String eventName, dynamic error) {
    logManager.logSocket(
      event: 'EVENT_PROCESSING_ERROR',
      data: {
        'eventName': eventName,
        'error': error.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      },
      error: error.toString(),
    );
  }

  /// Get current ride details
  Map<String, dynamic> getRideDetails() {
    return {
      'rideId': currentRideId.value,
      'status': rideStatus.value,
      'driverLocation': driverLocation.value,
      'passengerLocations': passengerLocations,
      'totalFare': totalFare.value,
      'estimatedArrival': estimatedArrival.value,
      'isConnected': isConnected.value,
    };
  }

  /// Reset shared ride state
  void resetState() {
    currentRideId.value = null;
    availableMatches.clear();
    passengerLocations.clear();
    pickupOTP.value = null;
    rideStatus.value = 'waiting';
    totalFare.value = 0.0;
    estimatedArrival.value = 0;
    rideDetails.value = {};
  }

  @override
  void onClose() {
    disconnect();
    _rideEventController.close();
    _errorController.close();
    super.onClose();
  }
}
