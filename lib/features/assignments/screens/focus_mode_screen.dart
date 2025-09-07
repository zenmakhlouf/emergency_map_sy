import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' show Distance, LengthUnit;

import '../models/participation_request.dart' as assignments;
import '../../auth/cubit/auth_cubit.dart';
import '../../users_location/cubit/userslocation_cubit.dart';
import '../../users_location/repo/locationservice.dart';
import '../../reports/cubit/reports_cubit.dart';
import '../../reports/models/report.dart';
import '../../../services/routing_service.dart';
import '../../../services/report_details_service.dart';
import '../../dashboard/helpers.dart';
import 'focus_mode_chat_widget.dart';

/// Routing status for professional error handling and retry mechanisms
enum RoutingStatus { 
  loading,     // Route calculation in progress
  success,     // Route successfully calculated
  failed,      // Route calculation failed
  unavailable, // Routing service unavailable
  disabled     // Routing disabled due to invalid locations
}

/// Comprehensive routing state management
class RoutingState {
  final RoutingStatus status;
  final String? errorMessage;
  final List<LatLng> route;
  final Duration? estimatedTime;
  final double? distance;
  final int retryAttempt;

  const RoutingState({
    required this.status,
    this.errorMessage,
    this.route = const [],
    this.estimatedTime,
    this.distance,
    this.retryAttempt = 0,
  });

  RoutingState copyWith({
    RoutingStatus? status,
    String? errorMessage,
    List<LatLng>? route,
    Duration? estimatedTime,
    double? distance,
    int? retryAttempt,
  }) {
    return RoutingState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      route: route ?? this.route,
      estimatedTime: estimatedTime ?? this.estimatedTime,
      distance: distance ?? this.distance,
      retryAttempt: retryAttempt ?? this.retryAttempt,
    );
  }
}

class FocusModeScreen extends StatefulWidget {
  final assignments.ParticipationRequest activeAssignment;
  final ReportEntity fullReport;        // Enhanced: Full report with actual location data
  final LatLng currentPosition;

  const FocusModeScreen({
    super.key,
    required this.activeAssignment,
    required this.fullReport,          // Required: Complete report information
    required this.currentPosition,
  });

  @override
  State<FocusModeScreen> createState() => _FocusModeScreenState();
}

class _FocusModeScreenState extends State<FocusModeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  
  // Controllers and state
  final MapController _mapController = MapController();
  late AnimationController _pulseAnimationController;
  Timer? _locationUpdateTimer;
  Timer? _routeUpdateTimer;

  // Position and routing
  LatLng _currentPosition = const LatLng(33.5138, 36.2765);
  LatLng? _incidentLocation;
  RoutingState _routingState = const RoutingState(status: RoutingStatus.loading);
  bool _isInitializing = true;
  double _distanceToIncident = 0.0;

  // Live data
  List<UserLocationEntity> _otherResponders = [];
  bool _isLocationTracking = true;

  // Configuration
  static const Duration _locationUpdateInterval = Duration(seconds: 5);
  static const Duration _routeUpdateInterval = Duration(seconds: 20);
  static const double _focusZoomLevel = 16.0;

  @override
  void initState() {
    super.initState();
    
    debugPrint('🎯 [FOCUS_MODE] ========== INITIALIZING FOCUS MODE ==========');
    debugPrint('🎯 [FOCUS_MODE] Assignment ID: ${widget.activeAssignment.id}');
    debugPrint('🎯 [FOCUS_MODE] Report ID: ${widget.fullReport.id}');
    debugPrint('🎯 [FOCUS_MODE] Assignment Status: ${widget.activeAssignment.status}');
    debugPrint('🎯 [FOCUS_MODE] Current Position: ${widget.currentPosition}');
    debugPrint('🎯 [FOCUS_MODE] Responder: ${widget.activeAssignment.responder.name}');
    debugPrint('🎯 [FOCUS_MODE] Initiator: ${widget.activeAssignment.initiator.name}');
    debugPrint('🎯 [FOCUS_MODE] Report Name: ${widget.fullReport.state?.report?.name ?? "Unknown"}');
    debugPrint('🎯 [FOCUS_MODE] Emergency Type: ${widget.fullReport.state?.emergencyType ?? "Unknown"}');
    
    WidgetsBinding.instance.addObserver(this);
    _currentPosition = widget.currentPosition;
    
    // Extract REAL incident location from full report data
    _incidentLocation = _extractIncidentLocation();
    debugPrint('🎯 [FOCUS_MODE] Incident location set to: $_incidentLocation');
    debugPrint('🎯 [FOCUS_MODE] Location source: ${_getLocationSource()}');
    
    _initializeAnimations();
    _initializeFocusMode();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationUpdateTimer?.cancel();
    _routeUpdateTimer?.cancel();
    _pulseAnimationController.dispose();
    
    // Stop user location polling when focus mode exits
    debugPrint('🎯 [FOCUS_MODE] 👥 Stopping user location polling on dispose...');
   // context.read<UsersLocationCubit>().stopUsersPolling();
    debugPrint('🎯 [FOCUS_MODE] ✅ User location polling stopped');
    
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startLocationTracking();
      _startRouteUpdates();
    } else if (state == AppLifecycleState.paused) {
      _stopLocationTracking();
      _stopRouteUpdates();
    }
  }

  void _initializeAnimations() {
    _pulseAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  // ============================================================================
  // LOCATION EXTRACTION & VALIDATION
  // ============================================================================

  /// Extracts incident location from full report data with improved fallback hierarchy
  LatLng _extractIncidentLocation() {
    try {
      // Primary: Use actual report coordinates
      final lat = widget.fullReport.latitude;
      final lon = widget.fullReport.longitude;
      
      debugPrint('🎯 [FOCUS_MODE] === LOCATION EXTRACTION DEBUG ===');
      debugPrint('🎯 [FOCUS_MODE] Report ID: ${widget.fullReport.id}');
      debugPrint('🎯 [FOCUS_MODE] Report coordinates: lat=$lat, lon=$lon');
      debugPrint('🎯 [FOCUS_MODE] Report coordinate types: lat=${lat.runtimeType}, lon=${lon.runtimeType}');
      debugPrint('🎯 [FOCUS_MODE] Report full address: "${widget.fullReport.fullAddress}"');
      debugPrint('🎯 [FOCUS_MODE] Report location object: ${widget.fullReport.location}');
      
      if (_isValidCoordinate(lat, lon)) {
        debugPrint('🎯 [FOCUS_MODE] ✅ Using valid report coordinates: $lat, $lon');
        return LatLng(lat, lon);
      }
      
      debugPrint('🚨 [FOCUS_MODE] Primary coordinates failed validation');
      
      // Secondary: Try to extract coordinates from location object if available
      // This handles cases where coordinates might be stored in the location object
      if (widget.fullReport.location != null) {
        try {
          final locationLat = widget.fullReport.location.latitude;
          final locationLon = widget.fullReport.location.longitude;
          debugPrint('🎯 [FOCUS_MODE] Location object coordinates: lat=$locationLat, lon=$locationLon');
          
          if (_isValidCoordinate(locationLat, locationLon)) {
            debugPrint('🎯 [FOCUS_MODE] ✅ Using location object coordinates: $locationLat, $locationLon');
            return LatLng(locationLat, locationLon);
          }
        } catch (e) {
          debugPrint('🚨 [FOCUS_MODE] Error parsing location object: $e');
        }
      } else {
        debugPrint('🚨 [FOCUS_MODE] No location object available');
      }
      
      // Additional: Try to parse coordinates from string format if they exist
      // Sometimes coordinates come as strings that need parsing
      try {
        if (lat != null && lon != null) {
          final parsedLat = lat is String ? double.tryParse(lat as String) : lat;
          final parsedLon = lon is String ? double.tryParse(lon as String) : lon;
          debugPrint('🎯 [FOCUS_MODE] Parsed coordinates: lat=$parsedLat, lon=$parsedLon');
          
          if (parsedLat != null && parsedLon != null && _isValidCoordinate(parsedLat, parsedLon)) {
            debugPrint('🎯 [FOCUS_MODE] ✅ Using parsed coordinates: $parsedLat, $parsedLon');
            return LatLng(parsedLat, parsedLon);
          }
        }
      } catch (e) {
        debugPrint('🚨 [FOCUS_MODE] Error parsing string coordinates: $e');
      }
      
      // Tertiary: Try geocoding from address if available
      final address = widget.fullReport.fullAddress;
      if (address.isNotEmpty && address != 'Unknown' && address != 'Live Location') {
        debugPrint('🎯 [FOCUS_MODE] Report has address but no coordinates: $address');
        debugPrint('🚨 [FOCUS_MODE] Geocoding service needed - using Damascus center as fallback');
      }
      
      // ABSOLUTE LAST RESORT: Damascus center with clear warning
      // NEVER use current responder position as incident location as it creates meaningless routing
      debugPrint('🚨 [FOCUS_MODE] 🆘 WARNING: Using Damascus center as absolute fallback - routing may be inaccurate');
      debugPrint('🚨 [FOCUS_MODE] This means no valid incident coordinates were found in:');
      debugPrint('🚨 [FOCUS_MODE]   - Primary coordinates: $lat, $lon');
      debugPrint('🚨 [FOCUS_MODE]   - Location object: ${widget.fullReport.location}');
      debugPrint('🚨 [FOCUS_MODE]   - Report address: "${widget.fullReport.fullAddress}"');
      debugPrint('🚨 [FOCUS_MODE] === END LOCATION EXTRACTION ===');
      return const LatLng(33.5138, 36.2765);
      
    } catch (e) {
      debugPrint('🚨 [FOCUS_MODE] Error extracting location: $e');
      debugPrint('🚨 [FOCUS_MODE] Using Damascus center due to extraction error');
      return const LatLng(33.5138, 36.2765);
    }
  }

  /// Validates if coordinates are reasonable for emergency response
  bool _isValidCoordinate(double? lat, double? lon) {
    debugPrint('🎯 [FOCUS_MODE] === COORDINATE VALIDATION ===');
    debugPrint('🎯 [FOCUS_MODE] Input: lat=$lat (${lat.runtimeType}), lon=$lon (${lon.runtimeType})');
    
    // Check for null coordinates
    if (lat == null || lon == null) {
      debugPrint('🚨 [FOCUS_MODE] ❌ Null coordinates detected');
      return false;
    }
    
    // Check for zero coordinates (often indicates unset/default values)
    if (lat == 0.0 && lon == 0.0) {
      debugPrint('🚨 [FOCUS_MODE] ❌ Zero coordinates detected (0,0)');
      return false;
    }
    
    // Check for obviously invalid coordinates
    if (lat.isNaN || lon.isNaN || lat.isInfinite || lon.isInfinite) {
      debugPrint('🚨 [FOCUS_MODE] ❌ NaN or infinite coordinates detected');
      return false;
    }
    
    // Check for reasonable latitude bounds (expanded for border areas)
    if (lat < 29.0 || lat > 41.0) {
      debugPrint('🚨 [FOCUS_MODE] ❌ Latitude out of bounds: $lat (expected: 29-41)');
      return false;
    }
    
    // Check for reasonable longitude bounds (expanded for border areas)  
    if (lon < 29.0 || lon > 46.0) {
      debugPrint('🚨 [FOCUS_MODE] ❌ Longitude out of bounds: $lon (expected: 29-46)');
      return false;
    }
    
    debugPrint('🎯 [FOCUS_MODE] ✅ Coordinates validation passed: lat=$lat, lon=$lon');
    return true;
  }

  /// Gets a human-readable description of the location source with improved accuracy
  String _getLocationSource() {
    final lat = widget.fullReport.latitude;
    final lon = widget.fullReport.longitude;
    
    if (_isValidCoordinate(lat, lon)) {
      return 'Actual incident coordinates';
    }
    
    // Check location object coordinates
    if (widget.fullReport.location != null) {
      try {
        final locationLat = widget.fullReport.location.latitude;
        final locationLon = widget.fullReport.location.longitude;
        if (_isValidCoordinate(locationLat, locationLon)) {
          return 'Location object coordinates';
        }
      } catch (e) {
        debugPrint('🚨 [FOCUS_MODE] Error checking location object: $e');
      }
    }
    
    // Check if address is available for potential geocoding
    final address = widget.fullReport.fullAddress;
    if (address != null && address.isNotEmpty && address != 'Unknown' && address != 'Live Location') {
      return 'Damascus center (address available for geocoding: $address)';
    }
    
    return 'Damascus center (no valid incident location found)';
  }

  Future<void> _initializeFocusMode() async {
    try {
      debugPrint('🎯 [FOCUS_MODE] Starting focus mode initialization...');
      
      // Get current precise location with high accuracy initially
      debugPrint('🎯 [FOCUS_MODE] Step 1: Getting current precise location');
      await _updateCurrentLocation(forceHighAccuracy: true);
      debugPrint('🎯 [FOCUS_MODE] ✅ Current location updated: $_currentPosition');
      
      // Calculate initial route to incident
      debugPrint('🎯 [FOCUS_MODE] Step 2: Calculating route to incident');
      await _calculateRouteToIncident();
      debugPrint('🎯 [FOCUS_MODE] ✅ Route calculation completed. Points: ${_routingState.route.length}');
      
      // Auto-zoom to show both positions
      debugPrint('🎯 [FOCUS_MODE] Step 3: Auto-focusing map on incident');
      _autoFocusMapOnIncident();
      debugPrint('🎯 [FOCUS_MODE] ✅ Map focused on incident location');
      
      // Start real-time updates
      debugPrint('🎯 [FOCUS_MODE] Step 4: Starting real-time updates');
      _startLocationTracking();
      _startRouteUpdates();
      debugPrint('🎯 [FOCUS_MODE] ✅ Real-time tracking started');
      
      // Load other responders assigned to same incident
      debugPrint('🎯 [FOCUS_MODE] Step 5: Loading other responders');
      _loadOtherResponders();
      debugPrint('🎯 [FOCUS_MODE] ✅ Other responders loading initiated');
      
      debugPrint('🎯 [FOCUS_MODE] ========== INITIALIZATION COMPLETE ==========');
      
    } catch (e, stackTrace) {
      debugPrint('🚨 [FOCUS_MODE] Focus mode initialization error: $e');
      debugPrint('🚨 [FOCUS_MODE] Stack trace: $stackTrace');
    } finally {
      if (mounted) {
        setState(() => _isInitializing = false);
        debugPrint('🎯 [FOCUS_MODE] Initialization flag set to false');
      }
    }
  }

  Future<void> _updateCurrentLocation({bool forceHighAccuracy = false}) async {
    try {
      final startTime = DateTime.now();
      debugPrint('🎯 [FOCUS_MODE] 📍 Getting GPS position (accuracy: ${forceHighAccuracy ? "high" : "balanced"})...');
      
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: forceHighAccuracy ? LocationAccuracy.high : LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 8),
      );
      
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime).inMilliseconds;
      
      debugPrint('🎯 [FOCUS_MODE] 📍 GPS position received in ${duration}ms: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}');
      debugPrint('🎯 [FOCUS_MODE] 📍 Accuracy: ${position.accuracy.toStringAsFixed(1)}m, Speed: ${position.speed?.toStringAsFixed(1) ?? "null"}m/s');
      
      if (mounted) {
        final oldPosition = _currentPosition;
        final newPosition = LatLng(position.latitude, position.longitude);
        
        setState(() {
          _currentPosition = newPosition;
        });
        
        // Calculate movement distance for debugging
        final Distance distance = Distance();
        final movementDistance = distance.as(LengthUnit.Meter, oldPosition, newPosition);
        debugPrint('🎯 [FOCUS_MODE] 📍 Movement: ${movementDistance.toStringAsFixed(1)}m from previous position');
        debugPrint('🎯 [FOCUS_MODE] 📍 State updated successfully');
        
        // Update server location
        _updateServerLocation(position);
        
        // Recalculate route if significant movement (>10m)
        if (movementDistance > 10.0) {
          debugPrint('🎯 [FOCUS_MODE] 🗺️ Significant movement detected, recalculating route...');
          _calculateRouteToIncident();
        }
      } else {
        debugPrint('🚨 [FOCUS_MODE] Widget not mounted, skipping position update');
      }
    } catch (e, stackTrace) {
      debugPrint('🚨 [FOCUS_MODE] Location update error: $e');
      debugPrint('🚨 [FOCUS_MODE] Location error stack trace: $stackTrace');
    }
  }

  Future<void> _updateServerLocation(Position position) async {
    try {
      debugPrint('🎯 [FOCUS_MODE] 🌐 Updating server location...');
      context.read<UsersLocationCubit>().updateLocationCoordinates(
        lat: position.latitude,
        lon: position.longitude,
        address: " ",
      );
      debugPrint('🎯 [FOCUS_MODE] ✅ Server location updated successfully');
    } catch (e) {
      debugPrint('🚨 [FOCUS_MODE] Server location update failed: $e');
    }
  }

  // ============================================================================
  // ROUTING CALCULATION WITH PROFESSIONAL ERROR HANDLING
  // ============================================================================

  Future<void> _calculateRouteToIncident() async {
    if (_incidentLocation == null) {
      debugPrint('🚨 [FOCUS_MODE] ❌ Cannot calculate route: incident location is null');
      setState(() {
        _routingState = const RoutingState(
          status: RoutingStatus.disabled,
          errorMessage: 'Incident location not available',
        );
      });
      return;
    }
    
    debugPrint('🎯 [FOCUS_MODE] === ROUTE CALCULATION DEBUG ===');
    debugPrint('🎯 [FOCUS_MODE] 🗺️ Starting route calculation...');
    debugPrint('🎯 [FOCUS_MODE] 🗺️ From (Current Position): $_currentPosition');
    debugPrint('🎯 [FOCUS_MODE] 🗺️ To (Incident Location): $_incidentLocation');
    debugPrint('🎯 [FOCUS_MODE] 🗺️ Distance check: ${_calculateStraightLineDistance(_currentPosition, _incidentLocation!)} km');
    
    // Check if we're trying to route to the same location (Damascus fallback issue)
    final distanceKm = _calculateStraightLineDistance(_currentPosition, _incidentLocation!);
    if (distanceKm < 0.01) {
      debugPrint('🚨 [FOCUS_MODE] ❌ Same location detected - incident and current position are the same');
      setState(() {
        _routingState = const RoutingState(
          status: RoutingStatus.disabled,
          errorMessage: 'Cannot route: incident location is same as current position',
        );
      });
      return;
    }
    
    // Set loading state
    setState(() {
      _routingState = _routingState.copyWith(
        status: RoutingStatus.loading,
        errorMessage: null,
      );
    });
    
    try {
      final routeResult = await RoutingService.getRoute(
        _currentPosition,
        _incidentLocation!,
        profile: 'driving',
      );
      
      debugPrint('🎯 [FOCUS_MODE] 🗺️ Route service response received');
      debugPrint('🎯 [FOCUS_MODE] 🗺️ Route valid: ${routeResult.isValid}');
      
      if (routeResult.isValid && mounted) {
        // Validate that we're not routing from position to same position
        final isSameLocation = _calculateStraightLineDistance(_currentPosition, _incidentLocation!) < 0.01; // Less than 10m
        
        if (isSameLocation) {
          debugPrint('🚨 [FOCUS_MODE] ❌ Incident location same as current position - routing disabled despite route success');
          setState(() {
            _routingState = RoutingState(
              status: RoutingStatus.disabled,
              errorMessage: 'Incident location not available - cannot calculate meaningful route',
            );
            _distanceToIncident = 0.0;
          });
        } else {
          setState(() {
            _routingState = RoutingState(
              status: RoutingStatus.success,
              route: routeResult.geometry,
              distance: routeResult.distanceKm,
              estimatedTime: Duration(minutes: routeResult.durationMinutes.round()),
            );
            _distanceToIncident = routeResult.distanceKm;
          });
        }
        
        debugPrint('🎯 [FOCUS_MODE] ✅ Route calculation successful');
        debugPrint('🎯 [FOCUS_MODE] 🗺️ Route points: ${routeResult.geometry.length}');
        debugPrint('🎯 [FOCUS_MODE] 🗺️ Distance: ${routeResult.distanceKm} km');
        debugPrint('🎯 [FOCUS_MODE] 🗺️ Duration: ${routeResult.durationMinutes} minutes');
        
      } else {
        final errorMsg = routeResult.errorMessage ?? 'Unable to calculate route';
        debugPrint('🚨 [FOCUS_MODE] ❌ Route calculation failed: $errorMsg');
        
        // Only calculate fallback if incident location is not current position
        final isSameLocation = _calculateStraightLineDistance(_currentPosition, _incidentLocation!) < 0.01; // Less than 10m
        
        if (isSameLocation) {
          debugPrint('🚨 [FOCUS_MODE] ❌ Incident location same as current position - routing disabled');
          if (mounted) {
            setState(() {
              _routingState = RoutingState(
                status: RoutingStatus.disabled,
                errorMessage: 'Incident location not available - cannot calculate route',
              );
              _distanceToIncident = 0.0;
            });
          }
        } else {
          // Fallback to straight-line distance
          final straightDistance = _calculateStraightLineDistance(_currentPosition, _incidentLocation!);
          
          if (mounted) {
            setState(() {
              _routingState = RoutingState(
                status: RoutingStatus.failed,
                errorMessage: errorMsg,
                distance: straightDistance,
                retryAttempt: _routingState.retryAttempt,
              );
              _distanceToIncident = straightDistance;
            });
          }
        }
      }
    } catch (e, stackTrace) {
      debugPrint('🚨 [FOCUS_MODE] ❌ Route calculation error: $e');
      debugPrint('🚨 [FOCUS_MODE] Stack trace: $stackTrace');
      
      // Determine if this is a network issue or service unavailable
      final isNetworkIssue = e.toString().contains('network') || 
                            e.toString().contains('timeout') ||
                            e.toString().contains('connection');
      
      final status = isNetworkIssue ? RoutingStatus.unavailable : RoutingStatus.failed;
      final errorMsg = isNetworkIssue 
        ? 'Network connection issue. Check your internet connection.'
        : 'Routing service error: ${e.toString()}';
      
      // Only calculate fallback if incident location is not current position
      final isSameLocation = _calculateStraightLineDistance(_currentPosition, _incidentLocation!) < 0.01; // Less than 10m
      
      if (isSameLocation) {
        debugPrint('🚨 [FOCUS_MODE] ❌ Incident location same as current position - routing disabled');
        if (mounted) {
          setState(() {
            _routingState = RoutingState(
              status: RoutingStatus.disabled,
              errorMessage: 'Incident location not available - cannot calculate route',
            );
            _distanceToIncident = 0.0;
          });
        }
      } else {
        // Fallback to straight-line distance
        final straightDistance = _calculateStraightLineDistance(_currentPosition, _incidentLocation!);
        
        if (mounted) {
          setState(() {
            _routingState = RoutingState(
              status: status,
              errorMessage: errorMsg,
              distance: straightDistance,
              retryAttempt: _routingState.retryAttempt,
            );
            _distanceToIncident = straightDistance;
          });
        }
      }
    }
  }

  /// Calculates straight-line distance between two points as fallback
  double _calculateStraightLineDistance(LatLng from, LatLng to) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Kilometer, from, to);
  }

  /// Retry route calculation with exponential backoff
  Future<void> _retryRouteCalculation() async {
    if (_routingState.retryAttempt >= 3) {
      // Max retries reached
      setState(() {
        _routingState = _routingState.copyWith(
          status: RoutingStatus.unavailable,
          errorMessage: 'Maximum retry attempts reached. Routing service may be unavailable.',
        );
      });
      return;
    }

    // Exponential backoff delay
    final delaySeconds = [1, 3, 7][_routingState.retryAttempt];
    debugPrint('🎯 [FOCUS_MODE] Retrying route calculation in $delaySeconds seconds (attempt ${_routingState.retryAttempt + 1})');
    
    await Future.delayed(Duration(seconds: delaySeconds));
    
    setState(() {
      _routingState = _routingState.copyWith(retryAttempt: _routingState.retryAttempt + 1);
    });
    
    await _calculateRouteToIncident();
  }

  void _autoFocusMapOnIncident() {
    if (_incidentLocation == null) return;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      // Fit bounds to show both current position and incident
      final bounds = LatLngBounds.fromPoints([
        _currentPosition,
        _incidentLocation!,
      ]);
      
      _mapController.fitCamera(CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(50),
      ));
    });
  }

  void _startLocationTracking() {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = Timer.periodic(_locationUpdateInterval, (_) {
      if (_isLocationTracking) {
        _updateCurrentLocation();
      }
    });
  }

  void _stopLocationTracking() {
    _locationUpdateTimer?.cancel();
  }

  void _startRouteUpdates() {
    _routeUpdateTimer?.cancel();
    _routeUpdateTimer = Timer.periodic(_routeUpdateInterval, (_) {
      _calculateRouteToIncident();
    });
  }

  void _stopRouteUpdates() {
    _routeUpdateTimer?.cancel();
  }

  void _loadOtherResponders() {
    debugPrint('🎯 [FOCUS_MODE] 👥 Starting other responders polling...');
    // Start continuous polling of user locations for responders assigned to same incident
    context.read<UsersLocationCubit>().startUsersPolling();
    // Also fetch immediately for initial data
    context.read<UsersLocationCubit>().fetchUsersLocations();
    debugPrint('🎯 [FOCUS_MODE] ✅ Other responders polling started');
  }

  void _handleUsersLocationChange(UsersLocationState state) {
    if (!mounted) return;
    
    debugPrint('🎯 [FOCUS_MODE] 👥 User location state change: ${state.runtimeType}');
    
    if (state is UsersLocationSuccess) {
      debugPrint('🎯 [FOCUS_MODE] 👥 Received ${state.users.length} total users from server');
      
      // Filter users with location data first
      final usersWithLocation = state.users.where((user) => user.location != null).toList();
      debugPrint('🎯 [FOCUS_MODE] 👥 ${usersWithLocation.length} users have location data');
      
      // Filter responders (including all responders for visibility in focus mode)
      final allResponders = usersWithLocation.where((user) {
        final hasResponderRole = user.roles.any((role) => role.name == 'responder');
        debugPrint('🎯 [FOCUS_MODE] 👥 User ${user.name} (ID: ${user.id}) - Responder role: $hasResponderRole');
        return hasResponderRole;
      }).toList();
      
      debugPrint('🎯 [FOCUS_MODE] 👥 Found ${allResponders.length} responders with location');
      
      // For focus mode, show all responders (not just those assigned to same incident)
      // This provides better situational awareness for the responding user
      setState(() {
        _otherResponders = allResponders;
      });
      
      // Debug log each responder
      for (final responder in allResponders) {
        final location = responder.location!;
        debugPrint('🎯 [FOCUS_MODE] 👥 Responder: ${responder.name} at ${location.lat.toStringAsFixed(4)}, ${location.lon.toStringAsFixed(4)}');
      }
      
      debugPrint('🎯 [FOCUS_MODE] ✅ Other responders state updated with ${_otherResponders.length} users');
      
    } else if (state is UsersLocationError) {
      debugPrint('🚨 [FOCUS_MODE] 👥 User location error: ${state.message}');
    } else if (state is UsersLocationLoading) {
      debugPrint('🎯 [FOCUS_MODE] 👥 Loading user locations...');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildFocusAppBar(),
      body: _isInitializing ? _buildLoadingScreen() : _buildFocusContent(),
    );
  }

  PreferredSizeWidget _buildFocusAppBar() {
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'مهمة طوارئ نشطة',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Text(
            'بلاغ #${widget.activeAssignment.report.id}',
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
      backgroundColor: Colors.red.shade700,
      foregroundColor: Colors.white,
      elevation: 0,
      actions: [
        // ETA indicator - now handled in the routing status info
        // This section can be removed as it's replaced by the enhanced UI
        IconButton(
          icon: Icon(_isLocationTracking ? Icons.gps_fixed : Icons.gps_not_fixed),
          onPressed: () {
            setState(() => _isLocationTracking = !_isLocationTracking);
            if (_isLocationTracking) {
              _startLocationTracking();
            } else {
              _stopLocationTracking();
            }
          },
          tooltip: _isLocationTracking ? 'تتبع GPS نشط' : 'تتبع GPS متوقف',
        ),
      ],
    );
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.red.shade700),
          const SizedBox(height: 24),
          const Text(
            'تهيئة وضع التركيز...',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          const Text(
            'حساب المسار وتحديد الموقع',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildFocusContent() {
    return Stack(
      children: [
        // Map with routing
        _buildFocusMap(),
        
        // Distance and ETA overlay
        _buildNavigationOverlay(),
        
        // Draggable chat bottom sheet
        _buildDraggableChatSheet(),
      ],
    );
  }

  Widget _buildFocusMap() {
    return BlocListener<UsersLocationCubit, UsersLocationState>(
      listener: (context, state) => _handleUsersLocationChange(state),
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _currentPosition,
          initialZoom: _focusZoomLevel,
          minZoom: 1,
          maxZoom: 20,
          onPositionChanged: (camera, hasGesture) {
            // Optional: Handle map movements
          },
        ),
        children: [
          // Base map layer
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.emergency.map',
          ),
          
          // Route polyline - only show if we have a successful route
          if (_routingState.status == RoutingStatus.success && _routingState.route.isNotEmpty)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: _routingState.route,
                  strokeWidth: 6.0,
                  color: Colors.blue.shade600,
                  borderStrokeWidth: 2.0,
                  borderColor: Colors.white,
                ),
              ],
            ),
          
          // Markers layer
          MarkerLayer(
            markers: _buildFocusMarkers(),
          ),
        ],
      ),
    );
  }

  List<Marker> _buildFocusMarkers() {
    final markers = <Marker>[];
    
    // Current responder position
    markers.add(_buildCurrentResponderMarker());
    
    // Incident location
    if (_incidentLocation != null) {
      markers.add(_buildIncidentMarker());
    }
    
    // Other assigned responders
    for (final responder in _otherResponders) {
      if (responder.location != null) {
        markers.add(_buildOtherResponderMarker(responder));
      }
    }
    
    return markers;
  }

  Marker _buildCurrentResponderMarker() {
    return Marker(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      point: _currentPosition,
      child: AnimatedBuilder(
        animation: _pulseAnimationController,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.blue.shade600,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3 + 0.3 * _pulseAnimationController.value),
                  blurRadius: 10 + 10 * _pulseAnimationController.value,
                  spreadRadius: 2 + 4 * _pulseAnimationController.value,
                ),
              ],
            ),
            child: const Icon(
              Icons.person_pin_circle,
              color: Colors.white,
              size: 24,
            ),
          );
        },
      ),
    );
  }

  Marker _buildIncidentMarker() {
    return Marker(
      width: 50,
      height: 50,
      alignment: Alignment.center,
      point: _incidentLocation!,
      child: GestureDetector(
        onTap: () => _showIncidentDetails(),
        child: AnimatedBuilder(
          animation: _pulseAnimationController,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.red.shade700,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.4 + 0.4 * _pulseAnimationController.value),
                    blurRadius: 12 + 12 * _pulseAnimationController.value,
                    spreadRadius: 3 + 5 * _pulseAnimationController.value,
                  ),
                ],
              ),
              child: const Icon(
                Icons.emergency,
                color: Colors.white,
                size: 28,
              ),
            );
          },
        ),
      ),
    );
  }

  /// Show incident details using ReportDetailsService singleton
  void _showIncidentDetails() {
    debugPrint('🎯 [FOCUS_MODE] Attempting to show incident details for report ${widget.fullReport.id}');
    
    if (ReportDetailsService.isDashboardAvailable) {
      final success = ReportDetailsService.showReport(widget.fullReport.id);
      if (success) {
        debugPrint('🎯 [FOCUS_MODE] ✅ Successfully showed report details via singleton service');
      } else {
        debugPrint('🚨 [FOCUS_MODE] Report ${widget.fullReport.id} not found in cached reports');
        _showFallbackIncidentDialog();
      }
    } else {
      debugPrint('🚨 [FOCUS_MODE] Dashboard not available for report details service');
      _showFallbackIncidentDialog();
    }
  }

  /// Fallback dialog when ReportDetailsService is not available
  void _showFallbackIncidentDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.emergency, color: Colors.red.shade700, size: 24),
            const SizedBox(width: 8),
            const Text('تفاصيل الحادث'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.fullReport.state?.report?.name != null) ...[
              Text(
                'اسم البلاغ:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
              Text(widget.fullReport.state!.report!.name!),
              const SizedBox(height: 12),
            ],
            Text(
              'نوع الطوارئ:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            Text(widget.fullReport.state?.emergencyType ?? 'غير محدد'),
            const SizedBox(height: 12),
            Text(
              'الموقع:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            Text(widget.fullReport.fullAddress),
            const SizedBox(height: 12),
            Text(
              'المسافة:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            Text('${_distanceToIncident.toStringAsFixed(1)} كم'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  Marker _buildOtherResponderMarker(UserLocationEntity responder) {
    final location = responder.location!;
    return Marker(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      point: LatLng(location.lat, location.lon),
      child: GestureDetector(
        onTap: () => _showResponderDetails(responder),
        child: Container(
          decoration: BoxDecoration(
            color: getUserRoleColor(responder.primaryRole),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            getUserRoleIcon(responder.primaryRole),
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationOverlay() {
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Column(
        children: [
          // Main navigation info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Distance
                Expanded(
                  child: _buildNavInfo(
                    icon: Icons.straighten,
                    label: 'المسافة',
                    value: '${_distanceToIncident.toStringAsFixed(1)} km',
                    color: Colors.blue.shade600,
                    subtitle: _getDistanceSubtitle(),
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.grey.shade300,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                ),
                // ETA or Route Status
                Expanded(
                  child: _buildRouteStatusInfo(),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.grey.shade300,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                ),
                // Location tracking toggle
                Expanded(
                  child: _buildLocationTrackingInfo(),
                ),
              ],
            ),
          ),
          
          // Route error banner with retry button
          if (_routingState.status == RoutingStatus.failed ||
              _routingState.status == RoutingStatus.unavailable ||
              _routingState.status == RoutingStatus.disabled)
            _buildRoutingErrorBanner(),
        ],
      ),
    );
  }

  /// Enhanced route status information with professional error handling
  Widget _buildRouteStatusInfo() {
    switch (_routingState.status) {
      case RoutingStatus.loading:
        return _buildNavInfo(
          icon: Icons.sync,
          label: 'المسار',
          value: 'جاري الحساب...',
          color: Colors.orange.shade600,
          isAnimated: true,
        );
      
      case RoutingStatus.success:
        return _buildNavInfo(
          icon: Icons.navigation,
          label: 'الوقت المتوقع',
          value: '${_routingState.estimatedTime?.inMinutes ?? 0} دقيقة',
          color: Colors.green.shade600,
          subtitle: 'مسار محدث',
        );
      
      case RoutingStatus.failed:
        return _buildNavInfo(
          icon: Icons.error_outline,
          label: 'المسار',
          value: 'خطأ',
          color: Colors.red.shade600,
          subtitle: 'مسافة مستقيمة',
        );
      
      case RoutingStatus.unavailable:
        return _buildNavInfo(
          icon: Icons.wifi_off,
          label: 'المسار',
          value: 'غير متاح',
          color: Colors.grey.shade600,
          subtitle: 'مسافة مستقيمة',
        );
      
      case RoutingStatus.disabled:
        return _buildNavInfo(
          icon: Icons.location_disabled,
          label: 'المسار',
          value: 'معطل',
          color: Colors.grey.shade600,
          subtitle: 'موقع غير صالح',
        );
    }
  }

  Widget _buildLocationTrackingInfo() {
    return GestureDetector(
      onTap: () {
        setState(() => _isLocationTracking = !_isLocationTracking);
        if (_isLocationTracking) {
          _startLocationTracking();
        } else {
          _stopLocationTracking();
        }
      },
      child: _buildNavInfo(
        icon: _isLocationTracking ? Icons.gps_fixed : Icons.gps_not_fixed,
        label: 'تتبع الموقع',
        value: _isLocationTracking ? 'نشط' : 'متوقف',
        color: _isLocationTracking ? Colors.green.shade600 : Colors.grey.shade600,
      ),
    );
  }

  /// Error banner for routing issues with retry functionality
  Widget _buildRoutingErrorBanner() {
    if (_routingState.status == RoutingStatus.disabled) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.grey.shade600, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'الموقع غير صالح - يتم عرض المسافة المستقيمة',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final isRetryable = _routingState.status == RoutingStatus.failed ||
                       _routingState.status == RoutingStatus.unavailable;
    
    final backgroundColor = _routingState.status == RoutingStatus.unavailable
        ? Colors.orange.shade50
        : Colors.red.shade50;
    
    final borderColor = _routingState.status == RoutingStatus.unavailable
        ? Colors.orange.shade200
        : Colors.red.shade200;
    
    final iconColor = _routingState.status == RoutingStatus.unavailable
        ? Colors.orange.shade600
        : Colors.red.shade600;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(
            _routingState.status == RoutingStatus.unavailable
                ? Icons.wifi_off
                : Icons.error_outline,
            color: iconColor,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _routingState.status == RoutingStatus.unavailable
                      ? 'خدمة التنقل غير متاحة'
                      : 'فشل حساب المسار',
                  style: TextStyle(
                    color: iconColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_routingState.errorMessage != null)
                  Text(
                    _routingState.errorMessage!,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ),
          if (isRetryable)
            TextButton(
              onPressed: _retryRouteCalculation,
              style: TextButton.styleFrom(
                foregroundColor: iconColor,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh, size: 14, color: iconColor),
                  const SizedBox(width: 4),
                  Text(
                    'إعادة المحاولة',
                    style: TextStyle(fontSize: 11, color: iconColor),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _getDistanceSubtitle() {
    switch (_routingState.status) {
      case RoutingStatus.success:
        return 'مسار محسوب';
      case RoutingStatus.failed:
      case RoutingStatus.unavailable:
      case RoutingStatus.disabled:
        return 'مسافة مستقيمة';
      case RoutingStatus.loading:
        return 'جاري الحساب';
    }
  }

  Widget _buildNavInfo({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    String? subtitle,
    bool isAnimated = false,
  }) {
    final iconWidget = isAnimated
        ? AnimatedBuilder(
            animation: _pulseAnimationController,
            builder: (context, child) {
              return Transform.rotate(
                angle: _pulseAnimationController.value * 2 * 3.14159,
                child: Icon(icon, color: color, size: 20),
              );
            },
          )
        : Icon(icon, color: color, size: 20);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        iconWidget,
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          textAlign: TextAlign.center,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildDraggableChatSheet() {
    // Get conversation ID from the assignment's report
    final conversationId = widget.activeAssignment.report.id; // Using report ID as conversation ID
    
    return FocusModeChatWidget(
      conversationId: conversationId,
      chatTitle: _getReportDisplayName(),
      currentUserId: context.read<AuthCubit>().userId ?? 0,
    );
  }

  String _getReportDisplayName() {
    try {
      // Try to find the full report data from the reports cubit
      final reportsCubit = context.read<ReportsCubit>();
      final reportsState = reportsCubit.state;
      
      if (reportsState is ReportsSuccess) {
        // Find the matching report by ID
        final fullReport = reportsState.reports.firstWhere(
          (report) => report.id == widget.activeAssignment.report.id,
          orElse: () => throw StateError('Report not found'),
        );
        
        // Extract the report name from the state
        final reportName = fullReport.state?.report?.name;
        if (reportName != null && reportName.isNotEmpty) {
         // debugPrint('🎯 [FOCUS_MODE] Using report name: $reportName');
          return reportName;
        }
      }
      
      // Fallback to report ID format
      debugPrint('🎯 [FOCUS_MODE] Using fallback format for report ${widget.activeAssignment.report.id}');
      return 'بلاغ طوارئ #${widget.activeAssignment.report.id}';
    } catch (e) {
      debugPrint('🚨 [FOCUS_MODE] Error getting report name: $e');
      return 'بلاغ طوارئ #${widget.activeAssignment.report.id}';
    }
  }

  void _showResponderDetails(UserLocationEntity responder) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: CircleAvatar(
                backgroundColor: getUserRoleColor(responder.primaryRole),
                child: Icon(
                  getUserRoleIcon(responder.primaryRole),
                  color: Colors.white,
                ),
              ),
              title: Text(responder.name),
              subtitle: Text(responder.primaryRole),
            ),
            const SizedBox(height: 16),
            if (responder.location != null) ...[
              Text(
                'المسافة: ${calculateDistance(_currentPosition, LatLng(responder.location!.lat, responder.location!.lon)).toStringAsFixed(1)} km',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                'الموقع: ${responder.location!.address}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ],
        ),
      ),
    );
  }
}