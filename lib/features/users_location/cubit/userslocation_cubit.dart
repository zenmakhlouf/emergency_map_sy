import 'dart:async';
import 'package:emergency_map_sy/features/users_location/repo/locationservice.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';

/// Cubit for managing users location data and operations
class UsersLocationCubit extends Cubit<UsersLocationState> {
  final LocationService _locationService;
  Timer? _usersPollTimer;
  Timer? _locationPollTimer;

  // Configuration
  static const Duration _usersPollingInterval = Duration(seconds: 5);
  static const Duration _locationPollingInterval = Duration(seconds: 5);

  UsersLocationCubit({
    required LocationService locationService,
  })  : _locationService = locationService,
        super(const UsersLocationInitial());

  /// Fetch users locations once
  Future<void> fetchUsersLocations() async {
    // Only fetch if not already loading to prevent duplicate requests
    if (state is UsersLocationLoading) return;

    try {
      emit(const UsersLocationLoading());

      final response = await _locationService.getUsersLocations();

      // debugPrint("=== USERS LOCATION POLLING RESPONSE ===");
      // debugPrint("Response success: ${response.success}");
      // debugPrint("Response message: ${response.message}");
      // debugPrint("Total users count: ${response.users.length}");

      if (response.success) {
        // debugPrint("=== INDIVIDUAL USERS DATA ===");
        // for (int i = 0; i < response.users.length; i++) {
        //   final user = response.users[i];
        //   debugPrint("User $i:");
        //   debugPrint("  - ID: ${user.id}");
        //   debugPrint("  - Name: ${user.name}");
        //   debugPrint("  - Primary Role: ${user.primaryRole}");
        //   debugPrint("  - Has Valid Location: ${user.hasValidLocation}");
        //   if (user.location != null) {
        //     debugPrint("  - Location: lat=${user.location!.lat}, lon=${user.location!.lon}");
        //     debugPrint("  - Address: ${user.location!.address}");
        //   } else {
        //     debugPrint("  - Location: null");
        //   }
        //   debugPrint("  - Roles: ${user.roles.map((r) => r.name).join(', ')}");
        //   debugPrint("  ---");
        // }
        
        final validUsers =
            response.users.where((user) => user.hasValidLocation).toList();
            
        // debugPrint("=== FILTERING RESULTS ===");
        // debugPrint("Users with valid locations: ${validUsers.length}");
        // for (final user in validUsers) {
        //   debugPrint("Valid user: ${user.name} (${user.primaryRole}) at ${user.location!.lat}, ${user.location!.lon}");
        // }

        emit(UsersLocationSuccess(
          users: validUsers,
          lastUpdated: DateTime.now(),
        ));
      } else {
        debugPrint("Users location response failed: ${response.message}");
        emit(UsersLocationError(
          message: response.message ?? 'Failed to fetch users locations',
        ));
      }
    } on LocationServiceException catch (e) {
      debugPrint("Users location service exception: ${e.message} (${e.statusCode})");
      emit(UsersLocationError(message: e.message));
    } catch (e) {
      debugPrint('Users location unexpected error: $e');
      emit(const UsersLocationError(
        message: 'An unexpected error occurred while fetching user locations',
      ));
    }
  }

  /// Start polling for users locations
  void startUsersPolling() {
    // Cancel any existing timer to prevent multiple active timers
    stopUsersPolling();

    // Fetch immediately to get initial data
    fetchUsersLocations();

    // Then poll periodically
    _usersPollTimer = Timer.periodic(_usersPollingInterval, (_) {
      if (!isClosed) {
        fetchUsersLocations();
      }
    });

    debugPrint(
        'Started users location polling every ${_usersPollingInterval.inSeconds}s');
  }

  /// Stop polling for users locations
  void stopUsersPolling() {
    _usersPollTimer?.cancel();
    _usersPollTimer = null;
    debugPrint('Stopped users location polling');
  }

  /// Start polling user's own location to backend
  /// This method should be called with the latest known location.
  void startLocationPolling({
    required double lat,
    required double lon,
    String? address,
  }) {
    // Stop any existing timer to prevent multiple active timers
    stopLocationPolling();

    // Update immediately
    _updateLocationToBackend(lat: lat, lon: lon, address: address);

    // Then poll periodically with the provided coordinates
    _locationPollTimer = Timer.periodic(_locationPollingInterval, (_) {
      if (!isClosed) {
        _updateLocationToBackend(lat: lat, lon: lon, address: address);
      }
    });

    debugPrint(
        'Started location polling every ${_locationPollingInterval.inSeconds}s');
  }

  /// Stop polling user's location
  void stopLocationPolling() {
    _locationPollTimer?.cancel();
    _locationPollTimer = null;
    debugPrint('Stopped location polling');
  }

  /// Update location coordinates for polling
  /// This method is intended to update the coordinates used by the active polling timer.
  /// It restarts the polling with the new coordinates.
  void updateLocationCoordinates({
    required double lat,
    required double lon,
    String? address,
  }) {
    // Only restart if polling is currently active
    if (_locationPollTimer != null && _locationPollTimer!.isActive) {
      startLocationPolling(lat: lat, lon: lon, address: address);
    } else {
      // If polling is not active, just perform a one-time update
      _updateLocationToBackend(lat: lat, lon: lon, address: address);
    }
  }

  /// Internal method to update location to backend
  Future<void> _updateLocationToBackend({
    required double lat,
    required double lon,
    String? address,
  }) async {
    try {
      await _locationService.updateUserLocation(
        lat: lat,
        lon: lon,
        address: address,
      );
      debugPrint('Location updated: $lat, $lon');
    } catch (e) {
      debugPrint('Failed to update location to backend: $e');
      // Don't emit error state for location polling failures
      // as this is a background operation and might spam the UI.
      // Consider a separate mechanism for critical background errors if needed.
    }
  }

  /// Manually update user location (with error handling)
  /// This is for explicit, one-time updates, not for polling.
  Future<void> updateUserLocation({
    required double lat,
    required double lon,
    String? address,
  }) async {
    try {
      final response = await _locationService.updateLocationWithRetry(
        lat: lat,
        lon: lon,
        address: address,
      );

      if (response.success) {
        debugPrint('Location successfully updated to backend');
        // Optionally emit a success state or refresh users list
        // If this update implies a change in the current user's location
        // that should be reflected on the map, then fetching other users
        // might be appropriate here.
        fetchUsersLocations(); // Refresh other users' locations after our own update
      } else {
        emit(UsersLocationError(
            message: response.message ?? 'Failed to update location'));
      }
    } on LocationServiceException catch (e) {
      emit(UsersLocationError(
          message: 'Failed to update location: ${e.message}'));
    } catch (e) {
      emit(const UsersLocationError(
        message: 'Failed to update location. Please try again.',
      ));
    }
  }

  /// Get user by ID from current state
  UserLocationEntity? getUserById(int userId) {
    final currentState = state;
    if (currentState is UsersLocationSuccess) {
      try {
        return currentState.users.firstWhere((user) => user.id == userId);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /// Filter users by role
  List<UserLocationEntity> getUsersByRole(String role) {
    final currentState = state;
    if (currentState is UsersLocationSuccess) {
      switch (role.toLowerCase()) {
        case 'coordinator':
          return currentState.users
              .where((user) => user.isCoordinator)
              .toList();
        case 'responder':
          return currentState.users.where((user) => user.isResponder).toList();
        case 'citizen':
          return currentState.users.where((user) => user.isCitizen).toList();
        default:
          return [];
      }
    }
    return [];
  }

  /// Get users within a certain distance from a point
  List<UserLocationEntity> getUsersNearLocation({
    required double lat,
    required double lon,
    required double radiusKm,
  }) {
    final currentState = state;
    if (currentState is UsersLocationSuccess) {
      return currentState.users.where((user) {
        if (!user.hasValidLocation) return false;

        final distance = _calculateDistance(
          lat,
          lon,
          user.location!.lat,
          user.location!.lon,
        );

        return distance <= radiusKm;
      }).toList();
    }
    return [];
  }

  /// Calculate distance between two points in kilometers
  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    // Using Haversine formula for simplicity
    // In production, consider using a proper geolocation package
    const double earthRadius = 6371; // Earth radius in kilometers

    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);

    double a = (dLat / 2).abs() * (dLat / 2).abs() +
        _degreesToRadians(lat1).abs() *
            _degreesToRadians(lat2).abs() *
            (dLon / 2).abs() *
            (dLon / 2).abs();

    double c = 2 * (a.abs()).abs();

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (3.14159265359 / 180);
  }

  /// Refresh users data
  Future<void> refresh() async {
    await fetchUsersLocations();
  }

  @override
  Future<void> close() {
    stopUsersPolling();
    stopLocationPolling();
    return super.close();
  }
}

/// Base state for users location management
abstract class UsersLocationState extends Equatable {
  const UsersLocationState();

  @override
  List<Object?> get props => [];
}

/// Initial state
class UsersLocationInitial extends UsersLocationState {
  const UsersLocationInitial();
}

/// Loading state
class UsersLocationLoading extends UsersLocationState {
  const UsersLocationLoading();
}

/// Success state with users data
class UsersLocationSuccess extends UsersLocationState {
  final List<UserLocationEntity> users;
  final DateTime lastUpdated;

  const UsersLocationSuccess({
    required this.users,
    required this.lastUpdated,
  });

  @override
  List<Object?> get props => [users, lastUpdated];

  /// Get users count by role
  int getUsersCountByRole(String role) {
    switch (role.toLowerCase()) {
      case 'coordinator':
        return users.where((user) => user.isCoordinator).length;
      case 'responder':
        return users.where((user) => user.isResponder).length;
      case 'citizen':
        return users.where((user) => user.isCitizen).length;
      default:
        return 0;
    }
  }

  /// Check if data is stale (older than specified duration)
  bool isDataStale(Duration threshold) {
    return DateTime.now().difference(lastUpdated) > threshold;
  }

  /// Create updated state with new users
  UsersLocationSuccess copyWith({
    List<UserLocationEntity>? users,
    DateTime? lastUpdated,
  }) {
    return UsersLocationSuccess(
      users: users ?? this.users,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

/// Error state
class UsersLocationError extends UsersLocationState {
  final String message;

  const UsersLocationError({
    required this.message,
  });

  @override
  List<Object?> get props => [message];
}
