import 'package:get/get.dart';
import 'package:hopper/api/dataSource/shared_ride_datasource.dart';
import 'package:hopper/Core/Services/shared_ride_socket_service.dart';

/// Repository pattern for shared ride functionality
/// Acts as intermediary between data sources and UI layer
class SharedRideRepository {
  final SharedRideDataSource _dataSource;
  final SharedRideSocketService _socketService;

  SharedRideRepository({
    required SharedRideDataSource dataSource,
    required SharedRideSocketService socketService,
  })  : _dataSource = dataSource,
        _socketService = socketService;

  // ─── Factory Constructor ───────────────────────────────────────────────────

  factory SharedRideRepository.instance() {
    return SharedRideRepository(
      dataSource: SharedRideDataSource(Get.find()),
      socketService: Get.find<SharedRideSocketService>(),
    );
  }

  // ─── Getters for Services ──────────────────────────────────────────────────

  SharedRideDataSource get dataSource => _dataSource;
  SharedRideSocketService get socketService => _socketService;

  // ─── Request & Matching ───────────────────────────────────────────────────

  /// Request a shared ride and get available matches
  Future<Map<String, dynamic>> requestSharedRide({
    required double pickupLatitude,
    required double pickupLongitude,
    required double dropLatitude,
    required double dropLongitude,
    required int passengerCount,
    String? specialRequests,
  }) async {
    try {
      // Make HTTP request
      final response = await _dataSource.requestSharedRide(
        pickupLatitude: pickupLatitude.toString(),
        pickupLongitude: pickupLongitude.toString(),
        dropLatitude: dropLatitude.toString(),
        dropLongitude: dropLongitude.toString(),
        passengerCount: passengerCount,
        specialRequests: specialRequests,
      );

      // Emit socket event
      _socketService.requestSharedRide({
        'pickupLocation': {
          'latitude': pickupLatitude,
          'longitude': pickupLongitude,
        },
        'dropLocation': {
          'latitude': dropLatitude,
          'longitude': dropLongitude,
        },
        'passengerCount': passengerCount,
        'specialRequests': specialRequests,
      });

      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Get available matches for a ride request
  Future<List<Map<String, dynamic>>> getAvailableMatches({
    required double pickupLatitude,
    required double pickupLongitude,
    required double dropLatitude,
    required double dropLongitude,
  }) async {
    try {
      return await _dataSource.getAvailableMatches(
        pickupLatitude: pickupLatitude,
        pickupLongitude: pickupLongitude,
        dropLatitude: dropLatitude,
        dropLongitude: dropLongitude,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Confirm a shared ride match
  Future<Map<String, dynamic>> confirmSharedRideMatch({
    required String matchId,
    required String rideId,
  }) async {
    try {
      final response = await _dataSource.confirmSharedRideMatch(
        matchId: matchId,
        rideId: rideId,
      );

      // Emit socket confirmation
      _socketService.confirmRideMatch(matchId);

      return response;
    } catch (e) {
      rethrow;
    }
  }

  // ─── Ride Details & Status ────────────────────────────────────────────────

  /// Get detailed information about a shared ride
  Future<Map<String, dynamic>> getRideDetails(String rideId) async {
    try {
      return await _dataSource.getRideDetails(rideId);
    } catch (e) {
      rethrow;
    }
  }

  /// Get current ride state from socket service
  Map<String, dynamic> getCurrentRideState() {
    return _socketService.getRideDetails();
  }

  // ─── Driver Actions ───────────────────────────────────────────────────────

  /// Accept a shared ride request (driver)
  Future<Map<String, dynamic>> acceptSharedRide({
    required String rideId,
    required String driverId,
  }) async {
    try {
      return await _dataSource.acceptSharedRide(
        rideId: rideId,
        driverId: driverId,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Update driver location in real-time
  void updateDriverLocation({
    required double latitude,
    required double longitude,
  }) {
    _socketService.updateDriverLocation(latitude, longitude);
  }

  /// Submit batch location updates (useful for multiple rides)
  Future<Map<String, dynamic>> batchUpdateDriverLocations({
    required List<Map<String, dynamic>> locations,
  }) async {
    try {
      return await _dataSource.batchUpdateDriverLocations(
        locations: locations,
      );
    } catch (e) {
      rethrow;
    }
  }

  // ─── Pickup & Verification ────────────────────────────────────────────────

  /// Verify pickup OTP
  Future<Map<String, dynamic>> verifyPickupOTP(String otp) async {
    try {
      final rideId = _socketService.currentRideId.value;
      if (rideId == null) {
        throw Exception('No active ride');
      }

      final response = await _dataSource.verifyPickupOTP(
        rideId: rideId,
        otp: otp,
      );

      // Emit socket verification
      _socketService.verifyPickupOTP(otp);

      return response;
    } catch (e) {
      rethrow;
    }
  }

  // ─── Ride Completion ──────────────────────────────────────────────────────

  /// Complete a shared ride
  Future<Map<String, dynamic>> completeSharedRide({
    required double finalLatitude,
    required double finalLongitude,
    required double finalFare,
    Map<String, dynamic>? ratings,
  }) async {
    try {
      final rideId = _socketService.currentRideId.value;
      if (rideId == null) {
        throw Exception('No active ride');
      }

      final response = await _dataSource.completeSharedRide(
        rideId: rideId,
        finalLatitude: finalLatitude,
        finalLongitude: finalLongitude,
        finalFare: finalFare,
        ratings: ratings,
      );

      // Emit socket completion
      _socketService.completeSharedRide({
        'finalLocation': {
          'latitude': finalLatitude,
          'longitude': finalLongitude,
        },
        'finalFare': finalFare,
        'ratings': ratings,
      });

      return response;
    } catch (e) {
      rethrow;
    }
  }

  // ─── Cancellation ─────────────────────────────────────────────────────────

  /// Cancel a shared ride
  Future<Map<String, dynamic>> cancelSharedRide(String reason) async {
    try {
      final rideId = _socketService.currentRideId.value;
      if (rideId == null) {
        throw Exception('No active ride');
      }

      final response = await _dataSource.cancelSharedRide(
        rideId: rideId,
        reason: reason,
      );

      // Emit socket cancellation
      _socketService.cancelSharedRide(reason);

      return response;
    } catch (e) {
      rethrow;
    }
  }

  // ─── Analytics & History ──────────────────────────────────────────────────

  /// Get shared ride history for driver
  Future<List<Map<String, dynamic>>> getDriverSharedRideHistory({
    required String driverId,
    int? limit,
    int? offset,
  }) async {
    try {
      return await _dataSource.getDriverSharedRideHistory(
        driverId: driverId,
        limit: limit,
        offset: offset,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Get shared ride analytics and earnings
  Future<Map<String, dynamic>> getSharedRideAnalytics({
    required String driverId,
    String? period,
  }) async {
    try {
      return await _dataSource.getSharedRideAnalytics(
        driverId: driverId,
        period: period,
      );
    } catch (e) {
      rethrow;
    }
  }

  // ─── Ratings & Reviews ────────────────────────────────────────────────────

  /// Get ratings for a shared ride
  Future<Map<String, dynamic>> getRideRatings(String rideId) async {
    try {
      return await _dataSource.getRideRatings(rideId);
    } catch (e) {
      rethrow;
    }
  }

  /// Submit rating for a completed shared ride
  Future<Map<String, dynamic>> submitRideRating({
    required String rideId,
    required double rating,
    String? review,
    List<String>? tags,
  }) async {
    try {
      return await _dataSource.submitRideRating(
        rideId: rideId,
        rating: rating,
        review: review,
        tags: tags,
      );
    } catch (e) {
      rethrow;
    }
  }

  // ─── Observable Streams (from Socket Service) ─────────────────────────────

  /// Stream of ride events from socket
  Stream<Map<String, dynamic>> get rideEventStream =>
      _socketService.rideEventStream;

  /// Stream of socket errors
  Stream<String> get errorStream => _socketService.errorStream;

  // ─── Observable State (from Socket Service) ───────────────────────────────

  RxString get rideStatus => _socketService.rideStatus;
  RxDouble get totalFare => _socketService.totalFare;
  RxInt get estimatedArrival => _socketService.estimatedArrival;
  Rx<String?> get currentRideId => _socketService.currentRideId;
  RxBool get isSocketConnected => _socketService.isConnected;
  RxList<Map<String, dynamic>> get availableMatches =>
      _socketService.availableMatches;
  Rx<Map<String, double>> get driverLocation => _socketService.driverLocation;

  // ─── Socket Connection Management ──────────────────────────────────────────

  /// Connect socket service
  void connectSocket(String driverId, String authToken) {
    _socketService.connect(driverId, authToken);
  }

  /// Disconnect socket service
  void disconnectSocket() {
    _socketService.disconnect();
  }

  /// Reset shared ride state
  void resetState() {
    _socketService.resetState();
  }
}
