import 'package:hopper/api/api_client.dart';
import 'package:hopper/api/constants/api_constants.dart';

/// Data source for Shared Ride API endpoints
/// Handles HTTP requests for shared ride functionality
class SharedRideDataSource {
  final ApiClient _apiClient;

  SharedRideDataSource(this._apiClient);

  // ─── Shared Ride Endpoints ────────────────────────────────────────────────

  /// Request a shared ride
  /// POST /api/shared-rides/request
  Future<Map<String, dynamic>> requestSharedRide({
    required String pickupLatitude,
    required String pickupLongitude,
    required String dropLatitude,
    required String dropLongitude,
    required int passengerCount,
    String? specialRequests,
  }) async {
    try {
      final response = await _apiClient.post(
        '${ApiConstants.baseUrl}/api/shared-rides/request',
        data: {
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
          'requestedAt': DateTime.now().toIso8601String(),
        },
      );

      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Confirm shared ride match
  /// POST /api/shared-rides/confirm-match
  Future<Map<String, dynamic>> confirmSharedRideMatch({
    required String matchId,
    required String rideId,
  }) async {
    try {
      final response = await _apiClient.post(
        '${ApiConstants.baseUrl}/api/shared-rides/confirm-match',
        data: {
          'matchId': matchId,
          'rideId': rideId,
          'confirmedAt': DateTime.now().toIso8601String(),
        },
      );

      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Get shared ride details
  /// GET /api/shared-rides/:rideId
  Future<Map<String, dynamic>> getRideDetails(String rideId) async {
    try {
      final response = await _apiClient.get(
        '${ApiConstants.baseUrl}/api/shared-rides/$rideId',
      );

      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Accept shared ride (driver)
  /// POST /api/shared-rides/:rideId/accept
  Future<Map<String, dynamic>> acceptSharedRide({
    required String rideId,
    required String driverId,
  }) async {
    try {
      final response = await _apiClient.post(
        '${ApiConstants.baseUrl}/api/shared-rides/$rideId/accept',
        data: {
          'driverId': driverId,
          'acceptedAt': DateTime.now().toIso8601String(),
        },
      );

      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Update driver location
  /// POST /api/shared-rides/:rideId/update-location
  Future<Map<String, dynamic>> updateDriverLocation({
    required String rideId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final response = await _apiClient.post(
        '${ApiConstants.baseUrl}/api/shared-rides/$rideId/update-location',
        data: {
          'latitude': latitude,
          'longitude': longitude,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Verify pickup OTP
  /// POST /api/shared-rides/:rideId/verify-pickup
  Future<Map<String, dynamic>> verifyPickupOTP({
    required String rideId,
    required String otp,
  }) async {
    try {
      final response = await _apiClient.post(
        '${ApiConstants.baseUrl}/api/shared-rides/$rideId/verify-pickup',
        data: {
          'otp': otp,
          'verifiedAt': DateTime.now().toIso8601String(),
        },
      );

      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Complete shared ride
  /// POST /api/shared-rides/:rideId/complete
  Future<Map<String, dynamic>> completeSharedRide({
    required String rideId,
    required double finalLatitude,
    required double finalLongitude,
    required double finalFare,
    Map<String, dynamic>? ratings,
  }) async {
    try {
      final response = await _apiClient.post(
        '${ApiConstants.baseUrl}/api/shared-rides/$rideId/complete',
        data: {
          'dropLocation': {
            'latitude': finalLatitude,
            'longitude': finalLongitude,
          },
          'finalFare': finalFare,
          'ratings': ratings,
          'completedAt': DateTime.now().toIso8601String(),
        },
      );

      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Cancel shared ride
  /// POST /api/shared-rides/:rideId/cancel
  Future<Map<String, dynamic>> cancelSharedRide({
    required String rideId,
    required String reason,
  }) async {
    try {
      final response = await _apiClient.post(
        '${ApiConstants.baseUrl}/api/shared-rides/$rideId/cancel',
        data: {
          'reason': reason,
          'cancelledAt': DateTime.now().toIso8601String(),
        },
      );

      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Get available matches for shared ride
  /// GET /api/shared-rides/matches?pickupLat=X&pickupLng=Y&dropLat=X&dropLng=Y
  Future<List<Map<String, dynamic>>> getAvailableMatches({
    required double pickupLatitude,
    required double pickupLongitude,
    required double dropLatitude,
    required double dropLongitude,
  }) async {
    try {
      final queryParams = {
        'pickupLat': pickupLatitude.toString(),
        'pickupLng': pickupLongitude.toString(),
        'dropLat': dropLatitude.toString(),
        'dropLng': dropLongitude.toString(),
      };

      final response = await _apiClient.get(
        '${ApiConstants.baseUrl}/api/shared-rides/matches',
        queryParameters: queryParams,
      );

      // Convert response to list if it's a map with 'matches' key
      if (response is Map && response.containsKey('matches')) {
        return List<Map<String, dynamic>>.from(response['matches']);
      }

      return response is List
          ? List<Map<String, dynamic>>.from(response)
          : [];
    } catch (e) {
      rethrow;
    }
  }

  /// Get ride history for driver
  /// GET /api/shared-rides/driver/:driverId/history
  Future<List<Map<String, dynamic>>> getDriverSharedRideHistory({
    required String driverId,
    int? limit,
    int? offset,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (limit != null) queryParams['limit'] = limit;
      if (offset != null) queryParams['offset'] = offset;

      final response = await _apiClient.get(
        '${ApiConstants.baseUrl}/api/shared-rides/driver/$driverId/history',
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );

      if (response is Map && response.containsKey('rides')) {
        return List<Map<String, dynamic>>.from(response['rides']);
      }

      return response is List
          ? List<Map<String, dynamic>>.from(response)
          : [];
    } catch (e) {
      rethrow;
    }
  }

  /// Get earnings analytics for shared rides
  /// GET /api/shared-rides/driver/:driverId/analytics
  Future<Map<String, dynamic>> getSharedRideAnalytics({
    required String driverId,
    String? period, // 'today', 'week', 'month', 'all'
  }) async {
    try {
      final queryParams = period != null ? {'period': period} : null;

      final response = await _apiClient.get(
        '${ApiConstants.baseUrl}/api/shared-rides/driver/$driverId/analytics',
        queryParameters: queryParams,
      );

      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Batch update driver locations (for multiple shared rides)
  /// POST /api/shared-rides/batch-location-update
  Future<Map<String, dynamic>> batchUpdateDriverLocations({
    required List<Map<String, dynamic>> locations,
  }) async {
    try {
      final response = await _apiClient.post(
        '${ApiConstants.baseUrl}/api/shared-rides/batch-location-update',
        data: {
          'locations': locations,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Get ride rating and reviews
  /// GET /api/shared-rides/:rideId/ratings
  Future<Map<String, dynamic>> getRideRatings(String rideId) async {
    try {
      final response = await _apiClient.get(
        '${ApiConstants.baseUrl}/api/shared-rides/$rideId/ratings',
      );

      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Submit ride rating and review
  /// POST /api/shared-rides/:rideId/rate
  Future<Map<String, dynamic>> submitRideRating({
    required String rideId,
    required double rating,
    String? review,
    List<String>? tags,
  }) async {
    try {
      final response = await _apiClient.post(
        '${ApiConstants.baseUrl}/api/shared-rides/$rideId/rate',
        data: {
          'rating': rating,
          'review': review,
          'tags': tags,
          'submittedAt': DateTime.now().toIso8601String(),
        },
      );

      return response;
    } catch (e) {
      rethrow;
    }
  }
}
