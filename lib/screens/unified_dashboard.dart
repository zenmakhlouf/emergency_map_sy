import 'dart:async';
import 'dart:convert';
import 'package:emergency_map_sy/features/profile/screens/profile_screen.dart';
import 'package:emergency_map_sy/services/routing_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../features/reports/cubit/reports_cubit.dart';
import '../features/reports/models/report.dart';
import '../features/auth/cubit/auth_cubit.dart';
import '../features/auth/models/user_type.dart';
import '../features/chat/screens/ai_emergency_chat_screen.dart';
import '../features/chat/screens/chats_list_screen.dart';
import '../features/chat/screens/chat_conversation_screen.dart';
import '../features/chat/cubit/chat_cubit.dart';

// --- NEW IMPORTS ---
import '../features/users_location/cubit/userslocation_cubit.dart';
import '../features/users_location/repo/locationservice.dart';

/// A unified dashboard that adapts its interface based on user type
/// Provides real-time emergency reporting and monitoring capabilities
class UnifiedDashboardScreen extends StatefulWidget {
  final UserType userType;

  const UnifiedDashboardScreen({
    super.key,
    required this.userType,
  });

  @override
  State<UnifiedDashboardScreen> createState() => _UnifiedDashboardScreenState();
}

class _UnifiedDashboardScreenState extends State<UnifiedDashboardScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // Controllers and state management
  final MapController _mapController = MapController();
  late TabController _tabController;
  Timer? _reportPoller;
  final ScrollController _reportsScrollController = ScrollController();

  // Location and data state
  LatLng _currentPosition = const LatLng(33.5138, 36.2765); // Damascus default
  String _currentAddress = "Getting location...";
  List<ReportEntity> _cachedReports = <ReportEntity>[];
  List<ReportEntity> _filteredReports = <ReportEntity>[];
  ReportEntity? _activeAssignment; // Single active assignment
  DateTime? _lastSuccessfulRefresh;

  // --- NEW ---: User locations state
  List<UserLocationEntity> _otherUsers = [];

  // Filter and search state
  String _searchQuery = "";
  String? _selectedCategory;
  String? _selectedStatus;
  String _sortBy = "distance"; // Changed default to distance
  bool _sortAscending = true; // Changed to true for nearest first

  // UI state management
  bool _isInitializing = true;
  bool _isLocationLoading = false;
  bool _isRefreshing = false;
  String? _locationError;
  String? _networkError;

  // Routing State
  List<LatLng> _routePolyline = [];
  bool _isRouteLoading = false;

  // --- NEW ---: Zoom level visibility flags
  bool _showReportMarkersAtCurrentZoom = true;
  bool _showUserMarkersAtCurrentZoom = false;

  // Configuration constants
  static const Duration _pollInterval = Duration(seconds: 20);
  static const Duration _networkTimeout = Duration(seconds: 20);
  static const double _defaultZoom = 14.0;
  static const double _minZoomForReportMarkers = 8.0;
  // --- NEW ---: Users will only show up at a closer zoom level to prevent clutter
  static const double _minZoomForUserMarkers = 13.0;

  // Emergency type categories for filtering
  static const List<String> _emergencyCategories = [
    'medical',
    'fire',
    'police',
    'traffic',
    'other'
  ];

  // Status options for filtering
  static const List<String> _statusOptions = [
    'pending',
    'assigned',
    'in_progress',
    'resolved',
    'closed'
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeTabController();
    _initializeApp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cleanup();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _startPolling();
        // --- NEW ---: Restart user polling if conditions are met
        _manageUserPolling();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _stopPolling();
        // --- NEW ---: Stop user polling when app is paused
        context.read<UsersLocationCubit>().stopUsersPolling();
        break;
      default:
        break;
    }
  }

  // ============================================================================
  // INITIALIZATION METHODS
  // ============================================================================

  void _initializeTabController() {
    // All user types now have only 3 tabs: Map, Reports, Chat
    _tabController = TabController(length: 3, vsync: this);
  }

  /// Initialize the app by setting up auth and getting initial data
  Future<void> _initializeApp() async {
    try {
      await _initializeAuth();
      await _initializeLocation();
      await _loadInitialReports();
      _startPolling();
      // --- NEW ---: Conditionally start polling for other users' locations
      _manageUserPolling();
    } catch (e) {
      debugPrint("Initialization error: $e");
      _handleInitializationError(e);
    } finally {
      if (mounted) {
        setState(() => _isInitializing = false);
      }
    }
  }

  Future<void> _initializeAuth() async {
    await context.read<AuthCubit>().waitForInitialization();
  }

  /// Get user's current location with improved error handling
  Future<void> _initializeLocation() async {
    if (!mounted) return;

    setState(() {
      _isLocationLoading = true;
      _locationError = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw const LocationException('Location services are disabled');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw const LocationException('Location permission denied');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      if (mounted) {
        final newPosition = LatLng(position.latitude, position.longitude);
        setState(() {
          _currentPosition = newPosition;
          _locationError = null;
        });

        await _updateAddressFromCoordinates(newPosition);
        // --- NEW ---: Start sending our own location to the backend
        if (mounted) {
          context.read<UsersLocationCubit>().startLocationPolling(
                lat: newPosition.latitude,
                lon: newPosition.longitude,
                address: _currentAddress,
              );
        }
      }
    } catch (e) {
      debugPrint("Location error: $e");
      if (mounted) {
        setState(() {
          _locationError = _getLocationErrorMessage(e);
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLocationLoading = false);
      }
    }
  }

  /// Update address using OpenStreetMap Nominatim with Arabic support
  Future<void> _updateAddressFromCoordinates(LatLng position) async {
    try {
      final url = 'https://nominatim.openstreetmap.org/reverse'
          '?format=json'
          '&lat=${position.latitude}'
          '&lon=${position.longitude}'
          '&zoom=18'
          '&addressdetails=1'
          '&accept-language=ar,en';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'EmergencyMapApp/1.0',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        final displayName = data['display_name'] as String?;

        if (displayName != null && displayName.isNotEmpty) {
          setState(() {
            _currentAddress = displayName;
          });
        } else {
          _setFallbackAddress(position);
        }
      } else {
        _setFallbackAddress(position);
      }
    } catch (e) {
      debugPrint("Nominatim geocoding error: $e");
      _setFallbackAddress(position);
    }
  }

  void _setFallbackAddress(LatLng position) {
    if (mounted) {
      setState(() {
        _currentAddress =
            "${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}";
      });
    }
  }

  Future<void> _loadInitialReports() async {
    await _fetchReports();
  }

  // ============================================================================
  // DATA FETCHING METHODS
  // ============================================================================

  Future<void> _fetchReports() async {
    if (!mounted) return;

    try {
      await context.read<ReportsCubit>().fetchReports(
        query: {
          'map_list': 1,
          'get': 1,
          'location[lat]': _currentPosition.latitude,
          'location[lon]': _currentPosition.longitude,
          'location[address]': _currentAddress.toString(), // Ensure string
        },
      ).timeout(_networkTimeout);

      if (mounted) {
        setState(() {
          _lastSuccessfulRefresh = DateTime.now();
          _networkError = null;
        });
      }
    } catch (e) {
      debugPrint("Network error fetching reports: $e");
      if (mounted) {
        setState(() {
          _networkError = "Unable to fetch latest updates";
        });
      }
    }
  }

  Future<void> _handleManualRefresh() async {
    if (!mounted || _isRefreshing) return;

    setState(() => _isRefreshing = true);

    try {
      await _fetchReports();
      // --- NEW ---: Also refresh users if they are visible
      if (_canViewOtherUsers()) {
        await context.read<UsersLocationCubit>().fetchUsersLocations();
      }
      await _initializeLocation();
      _showSuccessSnackBar("Reports and location updated successfully");
    } catch (e) {
      _showErrorSnackBar("Failed to refresh data");
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  // ============================================================================
  // POLLING MANAGEMENT
  // ============================================================================

  void _startPolling() {
    if (!_showReportMarkersAtCurrentZoom) return;

    _stopPolling();
    _reportPoller = Timer.periodic(_pollInterval, (_) {
      if (mounted && _showReportMarkersAtCurrentZoom) _fetchReports();
    });
  }

  void _stopPolling() {
    _reportPoller?.cancel();
    _reportPoller = null;
  }

  /// --- NEW ---: Manages starting/stopping of user location polling based on permissions and zoom
  void _manageUserPolling() {
    if (_canViewOtherUsers() && _showUserMarkersAtCurrentZoom) {
      context.read<UsersLocationCubit>().startUsersPolling();
    } else {
      context.read<UsersLocationCubit>().stopUsersPolling();
    }
  }

  double _calculateDistance(LatLng pos1, LatLng pos2) {
    return Geolocator.distanceBetween(
          pos1.latitude,
          pos1.longitude,
          pos2.latitude,
          pos2.longitude,
        ) /
        1000;
  }

  // ============================================================================
  // FILTERING AND SEARCH METHODS
  // ============================================================================

  void _applyFiltersAndSearch() {
    List<ReportEntity> filtered = List.from(_cachedReports);

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((report) =>
              report.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              report.description
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ||
              (report.fullAddress
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase())))
          .toList();
    }

    // Apply category filter
    if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
      filtered = filtered
          .where((report) =>
              (report.state?.emergencyType ?? '').toLowerCase() ==
              _selectedCategory!.toLowerCase())
          .toList();
    }

    // Apply status filter
    if (_selectedStatus != null && _selectedStatus!.isNotEmpty) {
      filtered = filtered
          .where((report) =>
              (report.state?.status ?? 'pending').toLowerCase() ==
              _selectedStatus!.toLowerCase())
          .toList();
    }

    // Apply sorting with distance as default
    filtered.sort((a, b) {
      int comparison = 0;

      switch (_sortBy) {
        case "priority":
          comparison =
              (b.state?.severity ?? 0.0).compareTo(a.state?.severity ?? 0.0);
          break;
        case "distance":
          final distanceA = _calculateDistance(
              _currentPosition, LatLng(a.latitude, a.longitude));
          final distanceB = _calculateDistance(
              _currentPosition, LatLng(b.latitude, b.longitude));
          comparison = distanceA.compareTo(distanceB);
          break;
        case "date":
        default:
          comparison = b.createdAt.compareTo(a.createdAt);
          break;
      }

      return _sortAscending ? comparison : -comparison;
    });

    setState(() {
      _filteredReports = filtered;
    });
  }

  void _clearFilters() {
    setState(() {
      _searchQuery = "";
      _selectedCategory = null;
      _selectedStatus = null;
      _sortBy = "distance"; // Default to distance
      _sortAscending = true; // Nearest first
    });
    _applyFiltersAndSearch();
  }

  // ============================================================================
  // ROUTING & NAVIGATION METHODS
  // ============================================================================

  /// Fetches route from the routing service and displays it on the map
  Future<void> _getAndDisplayRoute(ReportEntity report) async {
    if (!mounted || _isRouteLoading) return;

    setState(() {
      _isRouteLoading = true;
      _routePolyline = []; // Clear previous route
    });

    try {
      final routeResult = await RoutingService.getRoute(
        _currentPosition,
        LatLng(report.latitude, report.longitude),
      );

      if (routeResult.isValid && mounted) {
        setState(() {
          _routePolyline = routeResult.geometry;
        });

        // Fit map to show the entire route with some padding
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(_routePolyline),
            padding:
                const EdgeInsets.symmetric(horizontal: 40.0, vertical: 60.0),
          ),
        );
      } else {
        _showErrorSnackBar(
            routeResult.errorMessage ?? 'Could not find a valid route');
      }
    } catch (e) {
      debugPrint("In-app routing error: $e");
      if (e is RoutingException) {
        _showErrorSnackBar(e.message);
      } else {
        _showErrorSnackBar('Failed to get directions. Check your connection.');
      }
    } finally {
      if (mounted) {
        setState(() => _isRouteLoading = false);
      }
    }
  }

  /// Clears the currently displayed route from the map
  void _clearRoute() {
    if (mounted) {
      setState(() {
        _routePolyline = [];
      });
      _showSuccessSnackBar("Route cleared");
    }
  }

  // ============================================================================
  // UI CONFIGURATION & PERMISSIONS
  // ============================================================================

  bool _canPerformCitizenActions() => true;

  bool _canPerformResponderActions() =>
      widget.userType == UserType.responder ||
      widget.userType == UserType.coordinator;

  /// --- NEW ---: Determines if the current user has permission to see other users' locations
  bool _canViewOtherUsers() {
    // Coordinators can always see other users
    if (widget.userType == UserType.coordinator) {
      return true;
    }
    // Responders can only see others when actively assigned to a report
    if (widget.userType == UserType.responder && _activeAssignment != null) {
      return true;
    }
    return false;
  }

  List<Tab> _getTabConfiguration() {
    // All user types now have the same 3 tabs
    return const [
      Tab(icon: Icon(Icons.map_outlined), text: 'Map'),
      Tab(icon: Icon(Icons.report_outlined), text: 'Reports'),
      Tab(icon: Icon(Icons.chat_outlined), text: 'Chat'),
    ];
  }

  List<Widget> _getTabViews() {
    return [
      _buildMapTab(),
      _buildReportsTab(),
      _buildChatTab(),
    ];
  }

  Widget? _getFloatingActionButton() {
    if (_canPerformCitizenActions()) {
      return FloatingActionButton(
        onPressed: _navigateToEmergencyChat,
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        elevation: 8,
        child: Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Text(
            '🚨',
            style: TextStyle(
              fontSize: 24,
            ),
          ),
        ),
      );
    }
    return null;
  }

  // ============================================================================
  // TAB BUILDERS
  // ============================================================================

  Widget _buildMapTab() {
    // Check if user has active assignment and is responder/coordinator
    if (_canPerformResponderActions() && _activeAssignment != null) {
      return _buildActiveAssignmentView();
    }

    // For citizens or users without active assignments
    if (widget.userType == UserType.citizen) {
      return _buildCitizenMapView();
    } else {
      return _buildResponderMapView();
    }
  }

  Widget _buildCitizenMapView() {
    return RefreshIndicator(
      onRefresh: _handleManualRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            //_buildLocationCard(),
            _buildMapSection(),
            _buildNearbyIncidentsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildResponderMapView() {
    return Stack(
      children: [
        _buildFullScreenMap(),
        _buildMapOverlayControls(),
        _buildZoomControls(),
      ],
    );
  }

  Widget _buildActiveAssignmentView() {
    if (_activeAssignment == null) return _buildResponderMapView();

    return Column(
      children: [
        _buildActiveAssignmentHeader(),
        Expanded(
          child: Stack(
            children: [
              _buildAssignmentMap(),
              _buildMapOverlayControls(),
              _buildZoomControls(),
            ],
          ),
        ),
        _buildActiveAssignmentActions(),
      ],
    );
  }

  Widget _buildActiveAssignmentHeader() {
    if (_activeAssignment == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border(bottom: BorderSide(color: Colors.blue.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade600,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'ACTIVE ASSIGNMENT',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              _buildSeverityIndicator(
                  _activeAssignment!.state?.severity ?? 0.5),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _activeAssignment!.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _activeAssignment!.fullAddress,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Distance: ${_calculateDistance(_currentPosition, LatLng(_activeAssignment!.latitude, _activeAssignment!.longitude)).toStringAsFixed(1)} km',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentMap() {
    if (_activeAssignment == null) return const SizedBox.shrink();

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter:
            LatLng(_activeAssignment!.latitude, _activeAssignment!.longitude),
        initialZoom: _defaultZoom,
        minZoom: 1,
        maxZoom: 40,
        onPositionChanged: _onMapPositionChanged,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.emergency.map',
        ),
        if (_routePolyline.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _routePolyline,
                strokeWidth: 5.0,
                color: Colors.deepPurpleAccent,
                borderStrokeWidth: 2.0,
                borderColor: Colors.white.withOpacity(0.8),
              ),
            ],
          ),
        MarkerLayer(
            markers: _buildAssignmentMarkers() + _buildUserMarkers(context)),
      ],
    );
  }

  List<Marker> _buildAssignmentMarkers() {
    if (_activeAssignment == null) return [];

    return [
      // User location marker
      Marker(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        point: _currentPosition,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.blue.shade600,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.person_pin_circle,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
      // Assignment location marker
      Marker(
        width: 50,
        height: 50,
        alignment: Alignment.center,
        point:
            LatLng(_activeAssignment!.latitude, _activeAssignment!.longitude),
        child: Container(
          decoration: BoxDecoration(
            color: _getColorForEmergencyType(
                _activeAssignment!.state?.emergencyType),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(
            _getIconForEmergencyType(_activeAssignment!.state?.emergencyType),
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    ];
  }

  Widget _buildActiveAssignmentActions() {
    if (_activeAssignment == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_routePolyline.isNotEmpty)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _clearRoute,
                icon: const Icon(Icons.clear_all),
                label: const Text('Clear Route'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue.shade600,
                  side: BorderSide(color: Colors.blue.shade600),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            )
          else
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isRouteLoading
                    ? null
                    : () => _getAndDisplayRoute(_activeAssignment!),
                icon: _isRouteLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.directions),
                label: const Text('Get Directions'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _updateAssignmentStatus('en_route'),
              icon: const Icon(Icons.directions_run),
              label: const Text('On My Way'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportsTab() {
    return RefreshIndicator(
      onRefresh: _handleManualRefresh,
      child: Column(
        children: [
          _buildReportsHeader(),
          _buildSearchAndFilters(),
          Expanded(
            child: _buildScrollableReportsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildChatTab() {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, authState) {
        if (context.read<AuthCubit>().isAuthenticated) {
          return const ChatsListScreen();
        }
        return _buildAuthRequiredMessage();
      },
    );
  }

  // ============================================================================
  // COMPONENT BUILDERS
  // ============================================================================

  Widget _buildMapSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 280,
          child: Stack(
            children: [
              _buildInteractiveMap(),
              if (_isLocationLoading) _buildLocationLoadingOverlay(),
              if (_locationError != null) _buildLocationErrorOverlay(),
              // Add "Go to My Location" button for citizens
              if (widget.userType == UserType.citizen)
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: _buildGoToLocationButton(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoToLocationButton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: const Icon(Icons.my_location),
        onPressed: _centerMapOnCurrentLocation,
        tooltip: 'Go to My Location',
        iconSize: 20,
        color: Colors.blue.shade600,
      ),
    );
  }

  Widget _buildInteractiveMap({double? zoom}) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _currentPosition,
        initialZoom: zoom ?? _defaultZoom,
        minZoom: 1,
        maxZoom: 40,
        onPositionChanged: _onMapPositionChanged,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.emergency.map',
        ),
        if (_routePolyline.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _routePolyline,
                strokeWidth: 5.0,
                color: Colors.deepPurpleAccent,
                borderStrokeWidth: 2.0,
                borderColor: Colors.white.withOpacity(0.8),
              ),
            ],
          ),
        MarkerLayer(markers: _buildAllMapMarkers(context)),
      ],
    );
  }

  Widget _buildFullScreenMap({double? zoom}) {
    return _buildInteractiveMap(zoom: zoom);
  }

  Widget _buildMapOverlayControls() {
    return Positioned(
      top: 16,
      right: 16,
      child: Column(
        children: [
          _buildMapControlButton(
            icon: Icons.refresh,
            onPressed: _isRefreshing ? null : _handleManualRefresh,
            tooltip: 'Refresh Reports',
          ),
          const SizedBox(height: 8),
          _buildMapControlButton(
            icon: Icons.my_location,
            onPressed: _centerMapOnCurrentLocation,
            tooltip: 'Center on Location',
          ),
          if (_canPerformResponderActions()) ...[
            const SizedBox(height: 8),
            _buildMapControlButton(
              icon: Icons.filter_list,
              onPressed: _showMapFilters,
              tooltip: 'Filters',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildZoomControls() {
    return Positioned(
      bottom: 100,
      right: 16,
      child: Column(
        children: [
          _buildMapControlButton(
            icon: Icons.add,
            onPressed: () => _mapController.move(
                _mapController.camera.center, _mapController.camera.zoom + 1),
            tooltip: 'Zoom In',
          ),
          const SizedBox(height: 8),
          _buildMapControlButton(
            icon: Icons.remove,
            onPressed: () => _mapController.move(
                _mapController.camera.center, _mapController.camera.zoom - 1),
            tooltip: 'Zoom Out',
          ),
        ],
      ),
    );
  }

  Widget _buildMapControlButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required String tooltip,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon),
        onPressed: onPressed,
        tooltip: tooltip,
        iconSize: 20,
      ),
    );
  }

  Widget _buildScrollableReportsList() {
    final reportsToShow = _filteredReports.isEmpty &&
            _searchQuery.isEmpty &&
            _selectedCategory == null &&
            _selectedStatus == null
        ? _cachedReports
        : _filteredReports;

    if (reportsToShow.isEmpty && !_isRefreshing) {
      return _buildEmptyState();
    }

    return ListView.builder(
      controller: _reportsScrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: reportsToShow.length,
      itemBuilder: (context, index) => _buildIncidentCard(reportsToShow[index]),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Column(
        children: [
          // Search bar
          TextField(
            onChanged: (value) {
              setState(() => _searchQuery = value);
              _applyFiltersAndSearch();
            },
            decoration: InputDecoration(
              hintText: 'Search reports...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() => _searchQuery = "");
                        _applyFiltersAndSearch();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),

          const SizedBox(height: 12),

          // Filter chips and sort
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  'Category',
                  _selectedCategory,
                  _emergencyCategories,
                  (value) => setState(() => _selectedCategory = value),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Status',
                  _selectedStatus,
                  _statusOptions,
                  (value) => setState(() => _selectedStatus = value),
                ),
                const SizedBox(width: 8),
                _buildSortChip(),
                const SizedBox(width: 8),
                if (_selectedCategory != null ||
                    _selectedStatus != null ||
                    _searchQuery.isNotEmpty)
                  ActionChip(
                    avatar: const Icon(Icons.clear, size: 16),
                    label: const Text('Clear'),
                    onPressed: _clearFilters,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String? selected, List<String> options,
      Function(String?) onSelected) {
    return PopupMenuButton<String>(
      child: Chip(
        avatar: Icon(
          selected != null ? Icons.filter_alt : Icons.filter_alt_outlined,
          size: 16,
        ),
        label: Text(
            selected != null ? '$label: ${selected.toUpperCase()}' : label),
        backgroundColor:
            selected != null ? Colors.blue.shade100 : Colors.grey.shade100,
      ),
      onSelected: (value) {
        onSelected(value == selected ? null : value);
        _applyFiltersAndSearch();
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: null, child: Text('All')),
        ...options.map((option) => PopupMenuItem(
              value: option,
              child: Text(option.toUpperCase()),
            )),
      ],
    );
  }

  Widget _buildSortChip() {
    return PopupMenuButton<String>(
      child: Chip(
        avatar: Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
            size: 16),
        label: Text('Sort: ${_sortBy.toUpperCase()}'),
        backgroundColor: Colors.green.shade100,
      ),
      onSelected: (value) {
        if (value == _sortBy) {
          setState(() => _sortAscending = !_sortAscending);
        } else {
          setState(() {
            _sortBy = value;
            _sortAscending = value == 'distance'
                ? true
                : false; // Nearest first for distance
          });
        }
        _applyFiltersAndSearch();
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'distance', child: Text('DISTANCE')),
        const PopupMenuItem(value: 'date', child: Text('DATE')),
        const PopupMenuItem(value: 'priority', child: Text('PRIORITY')),
      ],
    );
  }

  Widget _buildNearbyIncidentsSection() {
    // Sort nearby incidents by distance (nearest first)
    final nearbyReports = List<ReportEntity>.from(_cachedReports);
    nearbyReports.sort((a, b) {
      final distanceA =
          _calculateDistance(_currentPosition, LatLng(a.latitude, a.longitude));
      final distanceB =
          _calculateDistance(_currentPosition, LatLng(b.latitude, b.longitude));
      return distanceA.compareTo(distanceB);
    });

    // Take only the nearest 5 incidents
    final displayReports = nearbyReports.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Nearby Incidents',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              _buildNetworkStatusIndicator(),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: displayReports.length,
          itemBuilder: (context, index) =>
              _buildIncidentCard(displayReports[index]),
        ),
      ],
    );
  }

  Widget _buildReportsHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.3),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'All Reports',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              if (_lastSuccessfulRefresh != null)
                Text(
                  'Last updated: ${_formatTime(_lastSuccessfulRefresh!)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
            ],
          ),
          _buildNetworkStatusIndicator(),
        ],
      ),
    );
  }

  Widget _buildIncidentCard(ReportEntity report) {
    final emergencyType = report.state?.emergencyType;
    final severity = report.state?.severity ?? 0.5;
    final distance = _calculateDistance(
        _currentPosition, LatLng(report.latitude, report.longitude));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: () => _showReportDetails(report),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildIncidentIcon(emergencyType, severity),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        report.description,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      // Show geocoded address instead of coordinates
                      Text(
                        report.fullAddress,
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      _buildIncidentMetadata(report, distance),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildSeverityIndicator(severity),
                    const SizedBox(height: 8),
                    _buildQuickActions(report),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions(ReportEntity report) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.map, size: 20),
          onPressed: () => _locateReportOnMap(report),
          tooltip: 'View on Map',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
        if (_canPerformResponderActions())
          IconButton(
            icon: const Icon(Icons.chat, size: 20),
            onPressed: () => _navigateToReportChat(report),
            tooltip: 'Chat',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
      ],
    );
  }

  Widget _buildIncidentIcon(String? emergencyType, double severity) {
    final color = _getColorForEmergencyType(emergencyType);
    final icon = _getIconForEmergencyType(emergencyType);

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  Widget _buildIncidentMetadata(ReportEntity report, double distance) {
    return Row(
      children: [
        Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
        const SizedBox(width: 4),
        Text(
          '${report.formattedDate} - ${report.formattedTime}',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
          ),
        ),
        const Spacer(),
        Icon(Icons.location_on, size: 14, color: Colors.grey[500]),
        const SizedBox(width: 4),
        Text(
          '${distance.toStringAsFixed(1)} km',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }

  Widget _buildSeverityIndicator(double severity) {
    Color color;
    String label;
    if (severity >= 0.8) {
      color = Colors.red;
      label = 'HIGH';
    } else if (severity >= 0.6) {
      color = Colors.orange;
      label = 'MED';
    } else {
      color = Colors.yellow.shade700;
      label = 'LOW';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    String message = 'No incidents found';
    if (_searchQuery.isNotEmpty ||
        _selectedCategory != null ||
        _selectedStatus != null) {
      message = 'No incidents match your filters';
    }

    return Container(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            Icon(
              _searchQuery.isNotEmpty ||
                      _selectedCategory != null ||
                      _selectedStatus != null
                  ? Icons.search_off
                  : Icons.check_circle_outline,
              size: 64,
              color: _searchQuery.isNotEmpty ||
                      _selectedCategory != null ||
                      _selectedStatus != null
                  ? Colors.grey.shade400
                  : Colors.green.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty ||
                      _selectedCategory != null ||
                      _selectedStatus != null
                  ? 'No Results'
                  : 'All Clear',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _searchQuery.isNotEmpty ||
                        _selectedCategory != null ||
                        _selectedStatus != null
                    ? Colors.grey.shade600
                    : Colors.green.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthRequiredMessage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Authentication Required',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please sign in to access chat features and manage your conversations.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // OVERLAY BUILDERS
  // ============================================================================

  Widget _buildLocationLoadingOverlay() {
    return Container(
      color: Colors.white.withOpacity(0.9),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Getting your location...',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationErrorOverlay() {
    return Container(
      color: Colors.white.withOpacity(0.9),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off, size: 48, color: Colors.orange[700]),
            const SizedBox(height: 16),
            Text(
              _locationError!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _initializeLocation,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkStatusIndicator() {
    if (_isRefreshing) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text(
            'Updating...',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      );
    }

    if (_networkError != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.signal_wifi_off, size: 14, color: Colors.orange[700]),
          const SizedBox(width: 4),
          Text(
            'Offline',
            style: TextStyle(fontSize: 12, color: Colors.orange[700]),
          ),
        ],
      );
    }

    if (_lastSuccessfulRefresh != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 14, color: Colors.green[600]),
          const SizedBox(width: 4),
          Text(
            'Live',
            style: TextStyle(fontSize: 12, color: Colors.green[600]),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  // ============================================================================
  // MAP MARKERS AND INTERACTIONS
  // ============================================================================

  /// --- NEW ---: Handles map view changes to show/hide markers based on zoom level
  void _onMapPositionChanged(MapCamera camera, bool hasGesture) {
    if (hasGesture) {
      bool needsRebuild = false;

      // Check for report markers visibility
      final shouldShowReportMarkers = camera.zoom >= _minZoomForReportMarkers;
      if (_showReportMarkersAtCurrentZoom != shouldShowReportMarkers) {
        _showReportMarkersAtCurrentZoom = shouldShowReportMarkers;
        needsRebuild = true;
      }

      // Check for user markers visibility
      final shouldShowUserMarkers = camera.zoom >= _minZoomForUserMarkers;
      if (_showUserMarkersAtCurrentZoom != shouldShowUserMarkers) {
        _showUserMarkersAtCurrentZoom = shouldShowUserMarkers;
        needsRebuild = true;
      }

      if (needsRebuild) {
        setState(() {}); // Rebuild to add/remove markers
        // Manage polling based on new visibility
        _manageUserPolling();
        if (_showReportMarkersAtCurrentZoom) {
          _startPolling();
        } else {
          _stopPolling();
        }
      }
    }
  }

  /// Builds a combined list of all markers to be displayed on the map
  List<Marker> _buildAllMapMarkers(BuildContext context) {
    return [
      // Current user's location marker (always visible)
      Marker(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        point: _currentPosition,
        child: Container(
          decoration: BoxDecoration(
            color: _getUserRoleColor(widget.userType.name),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(Icons.person_pin_circle,
              color: Colors.white, size: 18),
        ),
      ),

      // Incident report markers
      ..._buildReportMarkers(),

      // Other users' location markers
      ..._buildUserMarkers(context),
    ];
  }

  /// Builds markers for incident reports
  List<Marker> _buildReportMarkers() {
    if (!_showReportMarkersAtCurrentZoom) return [];

    return _cachedReports.map((report) {
      final isActiveAssignment = _activeAssignment?.id == report.id;
      return Marker(
        width: isActiveAssignment ? 50 : 40,
        height: isActiveAssignment ? 50 : 40,
        alignment: Alignment.center,
        point: LatLng(report.latitude, report.longitude),
        child: GestureDetector(
          onTap: () => _showReportDetails(report),
          child: Container(
            decoration: BoxDecoration(
              color: _getColorForEmergencyType(report.state?.emergencyType),
              shape: BoxShape.circle,
              border: Border.all(
                color: isActiveAssignment ? Colors.yellow : Colors.white,
                width: isActiveAssignment ? 3 : 2,
              ),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: Icon(
              _getIconForEmergencyType(report.state?.emergencyType),
              color: Colors.white,
              size: isActiveAssignment ? 28 : 24,
            ),
          ),
        ),
      );
    }).toList();
  }

  /// --- NEW ---: Builds markers for other users' locations
  List<Marker> _buildUserMarkers(BuildContext context) {
    // Return empty list if user doesn't have permission or is zoomed out
    if (!_canViewOtherUsers() || !_showUserMarkersAtCurrentZoom) return [];

    // Ensure the current user is not drawn again from the list
    final currentUserId = context.read<AuthCubit>().userId;

    return _otherUsers
        .where((user) => user.id.toString() != currentUserId)
        .map((user) {
      return Marker(
        width: 25,
        height: 25,
        alignment: Alignment.center,
        point: LatLng(user.location!.lat, user.location!.lon),
        child: GestureDetector(
          onTap: () => _showUserDetails(user),
          child: Container(
            decoration: BoxDecoration(
              color: _getUserRoleColor(user.primaryRole),
              shape: BoxShape.rectangle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              _getUserRoleIcon(user.primaryRole),
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      );
    }).toList();
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  Color _getUserRoleColor(String? role) {
    switch (role) {
      case 'responder':
        return Colors.blue.shade600;
      case 'coordinator':
        return Colors.green.shade600;
      default:
        return Colors.teal.shade600;
    }
  }

  IconData _getUserRoleIcon(String? role) {
    switch (role) {
      case 'responder':
        return Icons.emergency;
      case 'coordinator':
        return Icons.support_agent;
      default:
        return Icons.person;
    }
  }

  IconData _getIconForEmergencyType(String? apiType) {
    switch ((apiType ?? '').toLowerCase()) {
      case 'fire':
        return Icons.local_fire_department;
      case 'police':
        return Icons.local_police;
      case 'medical':
        return Icons.medical_services;
      case 'rescue':
        return Icons.search;
      case 'natural_disaster':
        return Icons.warning;
      case 'traffic':
        return Icons.traffic;
      default:
        return Icons.report;
    }
  }

  Color _getColorForEmergencyType(String? apiType) {
    switch ((apiType ?? '').toLowerCase()) {
      case 'fire':
        return Colors.deepOrange.shade600;
      case 'police':
        return Colors.blue.shade600;
      case 'medical':
        return Colors.purple.shade600;
      case 'rescue':
        return Colors.green.shade600;
      case 'natural_disaster':
        return Colors.brown.shade600;
      case 'traffic':
        return Colors.amber.shade700;
      default:
        return Colors.grey.shade600;
    }
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _getLocationErrorMessage(dynamic error) {
    if (error is LocationException) {
      return error.message;
    }
    if (error.toString().contains('timeout')) {
      return 'Location request timed out';
    }
    return 'Unable to get location';
  }

  // ============================================================================
  // EVENT HANDLERS AND NAVIGATION
  // ============================================================================

  void _navigateToEmergencyChat() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AIEmergencyChatScreen()),
    );
  }

  void _navigateToReportChat(ReportEntity report) {
    final conversationId = report.conversation?.id;
    if (conversationId == null) {
      _showErrorSnackBar("No chat available for this report");
      return;
    }

    final authCubit = context.read<AuthCubit>();
    if (!authCubit.isAuthenticated || authCubit.userId == null) {
      _showErrorSnackBar("Please log in to access chat");
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<ChatCubit>(),
          child: ChatConversationScreen(
            chatId: conversationId,
            chatTitle: 'Emergency Report #${report.id}',
            currentUserId: authCubit.userId!,
            participants: const [], // Will be loaded by the screen
          ),
        ),
      ),
    );
  }

  Future<void> _centerMapOnCurrentLocation() async {
    if (_isLocationLoading) return;

    _mapController.move(_currentPosition, _defaultZoom);
    await _fetchReports();
  }

  void _locateReportOnMap(ReportEntity report) {
    final reportLocation = LatLng(report.latitude, report.longitude);

    // Switch to map tab (always index 0)
    _tabController.animateTo(0);

    // Center map on report location
    _mapController.move(reportLocation, _defaultZoom);

    _showSuccessSnackBar("Report located on map");
  }

  Future<void> _updateAssignmentStatus(String status) async {
    if (_activeAssignment == null) return;

    try {
      // Implement API call to update assignment status
      debugPrint("Updating assignment status to: $status");
      _showSuccessSnackBar("Status updated: ${status.replaceAll('_', ' ')}");
    } catch (e) {
      debugPrint("Error updating assignment status: $e");
      _showErrorSnackBar("Failed to update status");
    }
  }

  void _showMapFilters() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Map Filters',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _emergencyCategories.map((category) {
                final isSelected = _selectedCategory == category;
                return FilterChip(
                  label: Text(category.toUpperCase()),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedCategory = selected ? category : null;
                    });
                    _applyFiltersAndSearch();
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  _clearFilters();
                  Navigator.pop(context);
                },
                child: const Text('Clear All Filters'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showReportDetails(ReportEntity report) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildReportDetailsSheet(report),
    );
  }

  Widget _buildReportDetailsSheet(ReportEntity report) {
    return Container(
      margin: const EdgeInsets.only(top: 80),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with emergency type and severity
                  Row(
                    children: [
                      _buildIncidentIcon(
                        report.state?.emergencyType,
                        report.state?.severity ?? 0.5,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              report.title,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${report.formattedDate} at ${report.formattedTime}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Distance: ${_calculateDistance(_currentPosition, LatLng(report.latitude, report.longitude)).toStringAsFixed(1)} km',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildSeverityIndicator(report.state?.severity ?? 0.5),
                    ],
                  ),

                  const Divider(height: 32),

                  // Description
                  const Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    report.description,
                    style: const TextStyle(fontSize: 16, height: 1.5),
                  ),

                  const SizedBox(height: 24),

                  // Location section with geocoded address
                  _buildLocationSection(report),

                  const SizedBox(height: 24),

                  // Action buttons based on user type
                  _buildReportActionButtons(report),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// --- NEW ---: Shows a bottom sheet with details for the selected user
  void _showUserDetails(UserLocationEntity user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.only(top: 80),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _getUserRoleColor(user.primaryRole)
                              .withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getUserRoleIcon(user.primaryRole),
                          color: _getUserRoleColor(user.primaryRole),
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user.primaryRole.toUpperCase(),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  const Text(
                    'Last Known Location',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user.location?.address ?? 'Address not available',
                    style: const TextStyle(fontSize: 16, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // TODO: Implement contact functionality (e.g., chat, call)
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('Contact User'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSection(ReportEntity report) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Location',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                report.fullAddress,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Coordinates: ${report.latitude.toStringAsFixed(4)}, ${report.longitude.toStringAsFixed(4)}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReportActionButtons(ReportEntity report) {
    List<Widget> actionButtons = [];

    // Universal actions for all users
    actionButtons.addAll([
      Expanded(
        child: OutlinedButton.icon(
          onPressed: () {
            Navigator.pop(context);
            _locateReportOnMap(report);
          },
          icon: const Icon(Icons.map_outlined),
          label: const Text('View on Map'),
        ),
      ),
      const SizedBox(width: 12),
    ]);

    // Responder-specific actions
    if (_canPerformResponderActions()) {
      actionButtons.addAll([
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _assignToSelf(report);
            },
            icon: const Icon(Icons.assignment_turned_in),
            label: Text(widget.userType == UserType.responder
                ? 'Respond'
                : 'Assign to Me'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ]);
    }

    // Second row of actions
    List<Widget> secondRowActions = [];

    if (_canPerformResponderActions()) {
      secondRowActions.addAll([
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _getAndDisplayRoute(report);
            },
            icon: const Icon(Icons.directions),
            label: const Text('Directions'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _navigateToReportChat(report);
            },
            icon: const Icon(Icons.chat_outlined),
            label: const Text('Chat'),
          ),
        ),
      ]);
    }

    return Column(
      children: [
        Row(children: actionButtons),
        if (secondRowActions.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(children: secondRowActions),
        ],
      ],
    );
  }

  // ============================================================================
  // ASSIGNMENT MANAGEMENT
  // ============================================================================

  Future<void> _assignToSelf(ReportEntity report) async {
    try {
      // Implement API call to assign report to current user
      debugPrint("Assigning report ${report.id} to current user");

      setState(() {
        _activeAssignment = report;
      });

      _showSuccessSnackBar("Report assigned successfully");

      // --- NEW ---: Start polling for user locations now that we have an assignment
      _manageUserPolling();

      // Switch to map tab to show assignment
      _tabController.animateTo(0);
    } catch (e) {
      debugPrint("Error assigning report: $e");
      _showErrorSnackBar("Failed to assign report");
    }
  }

  // ============================================================================
  // ERROR HANDLING
  // ============================================================================

  void _handleInitializationError(dynamic error) {
    debugPrint("Initialization failed: $error");
    if (mounted) {
      setState(() {
        _networkError = "Failed to initialize app";
      });
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================================
  // LIFECYCLE MANAGEMENT
  // ============================================================================

  void _cleanup() {
    _stopPolling();
    // --- NEW ---: Ensure all cubit timers are cancelled
    context.read<UsersLocationCubit>().stopUsersPolling();
    context.read<UsersLocationCubit>().stopLocationPolling();
    _tabController.dispose();
    _reportsScrollController.dispose();
  }

  // ============================================================================
  // MAIN BUILD METHOD
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNavigation(),
      floatingActionButton: _getFloatingActionButton(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(_getAppTitle()),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      actions: [
        if (_networkError != null)
          IconButton(
            icon: Icon(Icons.signal_wifi_off, color: Colors.orange[700]),
            onPressed: _handleManualRefresh,
            tooltip: 'Connection Issues - Tap to Retry',
          ),
        if (_activeAssignment != null && _canPerformResponderActions())
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.shade600,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'ACTIVE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        IconButton(
          icon: const Icon(Icons.person_outline),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          ),
          tooltip: 'Profile',
        ),
      ],
    );
  }

  Widget _buildBody() {
    return MultiBlocListener(
      listeners: [
        BlocListener<ReportsCubit, ReportsState>(
          listener: _handleReportsStateChange,
        ),
        // --- NEW ---: Listener for the UsersLocationCubit
        BlocListener<UsersLocationCubit, UsersLocationState>(
          listener: (context, state) {
            if (state is UsersLocationSuccess) {
              setState(() {
                _otherUsers = state.users;
              });
            } else if (state is UsersLocationError) {
              // Optionally show a non-intrusive error for user location fetching
              debugPrint("Error fetching user locations: ${state.message}");
            }
          },
        ),
      ],
      child: _isInitializing
          ? _buildInitializationScreen()
          : TabBarView(
              controller: _tabController,
              children: _getTabViews(),
            ),
    );
  }

  Widget _buildBottomNavigation() {
    return Material(
      elevation: 8,
      child: TabBar(
        controller: _tabController,
        tabs: _getTabConfiguration(),
        labelColor: Theme.of(context).primaryColor,
        unselectedLabelColor: Colors.grey[600],
        indicatorColor: Theme.of(context).primaryColor,
        indicatorWeight: 3,
      ),
    );
  }

  Widget _buildInitializationScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(height: 24),
          Text(
            'Initializing SafetyConnect...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Setting up your emergency dashboard',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  String _getAppTitle() {
    switch (widget.userType) {
      case UserType.citizen:
        return 'SafetyConnect';
      case UserType.responder:
        return 'Emergency Response';
      case UserType.coordinator:
        return 'Emergency Operations';
    }
  }

  void _handleReportsStateChange(BuildContext context, ReportsState state) {
    if (!mounted) return;

    if (state is ReportsSuccess) {
      final previousAssignmentStatus = _activeAssignment != null;

      setState(() {
        _cachedReports = state.reports;
        _networkError = null;
        _lastSuccessfulRefresh = DateTime.now();

        if (_canPerformResponderActions()) {
          // final assignedReport = state.reports
          //     .where((report) =>
          //         report.state?.assignedTo ==
          //         int.tryParse(context.read<AuthCubit>().userId ?? ''))
          //     .firstOrNull;

          // _activeAssignment = assignedReport;
        }
      });

      // --- NEW ---: Check if assignment status changed to manage user polling
      if (previousAssignmentStatus != (_activeAssignment != null)) {
        _manageUserPolling();
      }

      _applyFiltersAndSearch();
    } else if (state is ReportsFailure) {
      setState(() {
        _networkError = state.message;
      });
    }
  }
}

// ============================================================================
// HELPER CLASSES
// ============================================================================

/// Custom exception for location-related errors
class LocationException implements Exception {
  final String message;

  const LocationException(this.message);

  @override
  String toString() => 'LocationException: $message';
}
