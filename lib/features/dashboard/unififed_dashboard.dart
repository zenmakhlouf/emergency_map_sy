import 'dart:async';
import 'dart:convert';
import 'package:emergency_map_sy/features/assignments/cubit/assignments_cubit.dart';
import 'package:emergency_map_sy/features/assignments/models/participation_request.dart';
import 'package:emergency_map_sy/features/assignments/screens/focus_mode_screen.dart';
import 'package:emergency_map_sy/features/auth/cubit/auth_cubit.dart';
import 'package:emergency_map_sy/features/auth/models/user_type.dart';
import 'package:emergency_map_sy/features/chat/cubit/chat_cubit.dart';
import 'package:emergency_map_sy/features/chat/screens/ai_emergency_chat_screen.dart';
import 'package:emergency_map_sy/features/chat/screens/chat_conversation_screen.dart';
import 'package:emergency_map_sy/features/chat/screens/chats_list_screen.dart';
import 'package:emergency_map_sy/features/dashboard/details_sheet.dart';
import 'package:emergency_map_sy/features/dashboard/helpers.dart';
import 'package:emergency_map_sy/features/dashboard/map_view.dart';
import 'package:emergency_map_sy/features/dashboard/reports_view.dart';
import 'package:emergency_map_sy/features/profile/screens/profile_screen.dart';
import 'package:emergency_map_sy/features/reports/cubit/reports_cubit.dart';
import 'package:emergency_map_sy/features/reports/models/report.dart' hide ParticipationRequest;
import 'package:emergency_map_sy/features/users_location/cubit/userslocation_cubit.dart';
import 'package:emergency_map_sy/features/users_location/repo/locationservice.dart';
import 'package:emergency_map_sy/screens/helper_functions.dart'
    hide getLocationErrorMessage;
import 'package:emergency_map_sy/services/map_navigation_service.dart';
import 'package:emergency_map_sy/services/routing_service.dart';
import 'package:emergency_map_sy/services/report_details_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

/// A unified dashboard that adapts its interface based on user type.
/// This widget manages the state and business logic, while delegating UI
/// rendering to specialized view widgets.
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
    with SingleTickerProviderStateMixin, WidgetsBindingObserver 
    implements UnifiedDashboardActions {
  // --- STATE MANAGEMENT ---
  final MapController _mapController = MapController();
  late TabController _tabController;
  Timer? _reportPoller;
  late UsersLocationCubit _usersLocationCubit;
  late AssignmentsCubit _assignmentsCubit;

  // --- LOCATION & DATA STATE ---
  LatLng _currentPosition = const LatLng(33.5138, 36.2765); // Damascus default
  String _currentAddress = "Getting location...";
  List<ReportEntity> _cachedReports = [];
  List<ReportEntity> _filteredReports = [];
  ReportEntity? _activeAssignment;
  DateTime? _lastSuccessfulRefresh;
  List<UserLocationEntity> _otherUsers = [];

  // --- FILTER & SEARCH STATE ---
  String _searchQuery = "";
  String? _selectedCategory;
  String? _selectedStatus;
  String _sortBy = "distance";
  bool _sortAscending = true;

  // --- UI STATE ---
  bool _isInitializing = true;
  bool _isLocationLoading = false;
  bool _isRefreshing = false;
  String? _locationError;
  String? _networkError;
  List<LatLng> _routePolyline = [];
  bool _isRouteLoading = false;
  bool _showReportMarkersAtCurrentZoom = true;
  bool _showUserMarkersAtCurrentZoom = false;

  // --- ASSIGNMENT NOTIFICATION STATE ---
  ParticipationRequest? _pendingAssignmentRequest;
  bool _isAssignmentNotificationVisible = false;
  bool _isProcessingAssignmentAction = false;

  // --- CONFIGURATION ---
  static const Duration _pollInterval = Duration(seconds: 5);
  static const Duration _networkTimeout = Duration(seconds: 5);
  static const double _defaultZoom = 14.0;
  static const double _minZoomForReportMarkers = 8.0;
  // Original zoom level (comment out for testing):
   static const double _minZoomForUserMarkers = 14.0;
  
  // TEST LINE: Set very low zoom to always show user markers
  //static const double _minZoomForUserMarkers = 1.0; // Always true for testing
  
  // FEATURE SWITCH: Comment out this line to disable coordinator user polling
  static const bool _enableCoordinatorUserPolling = true;
  // static const bool _enableCoordinatorUserPolling = false; // Uncomment to disable
  
  // FEATURE SWITCH: Comment out this line to disable responder user polling  
  //static const bool _enableResponderUserPolling = true;
   static const bool _enableResponderUserPolling = false; // Uncomment to disable
  static const List<String> _emergencyCategories = [
    'medical',
    'fire',
    'police',
    'traffic',
    'other'
  ];
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
    _usersLocationCubit = context.read<UsersLocationCubit>();
    _assignmentsCubit = context.read<AssignmentsCubit>();
    MapNavigationService().registerMapCenterCallback(_centerMapOnReportId);
    ReportDetailsService.registerDashboard(this);
    _tabController = TabController(length: 3, vsync: this);
    _initializeApp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    MapNavigationService().clearMapCenterCallback();
    ReportDetailsService.clearDashboard();
    _cleanup();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
      _manageUserPolling();
      _manageAssignmentPolling();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _stopPolling();
      _usersLocationCubit.stopUsersPolling();
      _assignmentsCubit.stopPolling();
    }
  }

  // ============================================================================
  // INITIALIZATION
  // ============================================================================

  Future<void> _initializeApp() async {
    try {
      await context.read<AuthCubit>().waitForInitialization();
      await _initializeLocation();
      await _fetchReports();
      
      // Force initial zoom level check since we changed the minimum zoom constants
      _updateZoomBasedVisibility(_defaultZoom);
      
      _startPolling();
      _manageUserPolling();
      _manageAssignmentPolling();
    } catch (e) {
      debugPrint("Initialization error: $e");
      if (mounted) setState(() => _networkError = "Failed to initialize app");
    } finally {
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  Future<void> _initializeLocation() async {
    if (!mounted) return;
    setState(() {
      _isLocationLoading = true;
      _locationError = null;
    });
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled)
        throw const LocationException('Location services are disabled');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied)
        permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw const LocationException('Location permission denied');
      }

      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best,
          timeLimit: const Duration(seconds: 10));
      if (mounted) {
        final newPosition = LatLng(position.latitude, position.longitude);
        setState(() => _currentPosition = newPosition);
        await _updateAddressFromCoordinates(newPosition);
        _usersLocationCubit.startLocationPolling(
            lat: newPosition.latitude,
            lon: newPosition.longitude,
            address: _currentAddress);
      }
    } catch (e) {
      if (mounted) setState(() => _locationError = getLocationErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isLocationLoading = false);
    }
  }

  Future<void> _updateAddressFromCoordinates(LatLng position) async {
    try {
      final url =
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}&zoom=18&addressdetails=1&accept-language=ar,en';
      final response = await http.get(Uri.parse(url), headers: {
        'User-Agent': 'EmergencyMapApp/1.0'
      }).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        final displayName = data['display_name'] as String?;
        if (displayName != null && displayName.isNotEmpty) {
          setState(() => _currentAddress = displayName);
        } else {
          _setFallbackAddress(position);
        }
      } else {
        _setFallbackAddress(position);
      }
    } catch (e) {
      _setFallbackAddress(position);
    }
  }

  void _setFallbackAddress(LatLng position) {
    if (mounted) {
      setState(() => _currentAddress =
          "${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}");
    }
  }

  // ============================================================================
  // DATA FETCHING & STATE HANDLING
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
          'location[address]': _currentAddress,
        },
      ).timeout(_networkTimeout);
      if (mounted)
        setState(() {
          _lastSuccessfulRefresh = DateTime.now();
          _networkError = null;
        });
    } catch (e) {
      if (mounted)
        setState(() => _networkError = "Unable to fetch latest updates");
    }
  }

  Future<void> _handleManualRefresh() async {
    if (!mounted || _isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      await _fetchReports();
      if (_canViewOtherUsers()) await _usersLocationCubit.fetchUsersLocations();
      await _initializeLocation();
      _showSuccessSnackBar("Reports and location updated successfully");
    } catch (e) {
      _showErrorSnackBar("Failed to refresh data");
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
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
        // Logic to find active assignment for current user can be added here
      });
      if (previousAssignmentStatus != (_activeAssignment != null)) {
        _manageUserPolling();
        // Force a rebuild since user marker visibility might have changed for responders
        setState(() {});
      }
      _applyFiltersAndSearch();
    } else if (state is ReportsFailure) {
      setState(() => _networkError = state.message);
    }
  }

  void _handleUsersLocationStateChange(
      BuildContext context, UsersLocationState state) {
    if (!mounted) return;
    debugPrint("=== USERS LOCATION STATE CHANGE ===");
    if (state is UsersLocationSuccess) {
      // debugPrint("Received ${state.users.length} users from UsersLocationCubit");
      // debugPrint("Users: ${state.users.map((u) => '${u.name}(${u.primaryRole})').join(', ')}");
      setState(() => _otherUsers = state.users);
   //   debugPrint("Updated _otherUsers, count: ${_otherUsers.length}");
    } else if (state is UsersLocationError) {
   ///   debugPrint("Error fetching user locations: ${state.message}");
    }
  }

  void _handleAssignmentsStateChange(
      BuildContext context, AssignmentsState state) {
    if (!mounted) return;

    // HIGH PRIORITY: Handle assigned mode activation
    if (state is AssignedMode && widget.userType == UserType.responder) {
      // print('🚀 [UnifiedDashboard] ASSIGNED MODE DETECTED!');
      // print('   📋 Report ID: ${state.activeAssignment.report.id}');
      // print('   🆕 First time: ${state.isFirstTime}');
      
      debugPrint('🎯 [FOCUS_MODE] AssignedMode detected in UnifiedDashboard');
      debugPrint('🎯 [FOCUS_MODE] Report ID: ${state.activeAssignment.report.id}');
      debugPrint('🎯 [FOCUS_MODE] First time assignment: ${state.isFirstTime}');
      debugPrint('🎯 [FOCUS_MODE] Assignment status: ${state.activeAssignment.status}');
      
      // Show prominent snackbar notification
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.assignment, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'تم تعيينك لمهمة!',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('تقرير ${state.activeAssignment.report.id}'),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green[700],
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'عرض',
            textColor: Colors.white,
            onPressed: () {
              // print('🎯 [UnifiedDashboard] User tapped to view assignment');
              debugPrint('🎯 [FOCUS_MODE] User tapped snackbar action to view assignment');
              debugPrint('🎯 [FOCUS_MODE] Navigating to focus mode...');
              _navigateToFocusMode(state.activeAssignment);
            },
          ),
        ),
      );
      return; // Exit early, don't process other state types
    }

    if (state is AssignmentsLoaded && widget.userType == UserType.responder) {
      // Check for new pending requests
      final pendingRequests = state.pendingRequests;
      if (pendingRequests.isNotEmpty && !_isAssignmentNotificationVisible) {
        // Show notification for the first pending request
        final newRequest = pendingRequests.first;
        setState(() {
          _pendingAssignmentRequest = newRequest;
          _isAssignmentNotificationVisible = true;
        });
      } else if (pendingRequests.isEmpty && _isAssignmentNotificationVisible) {
        // Hide notification if no pending requests
        _dismissAssignmentNotification();
      }
    } else if (state is AssignmentActionSuccess) {
      // Handle successful assignment actions
      _showSuccessSnackBar(state.message);
      if (state.action == 'accept') {
        // Navigate to focus mode automatically on accept
        _dismissAssignmentNotification();
        if (state.updatedRequest != null) {
          // Navigate to focus mode immediately
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _navigateToFocusMode(state.updatedRequest!);
          });
        }
      } else if (state.action == 'reject') {
        _dismissAssignmentNotification();
      }
    } else if (state is AssignmentsError) {
      _showErrorSnackBar("Assignment error: ${state.message}");
    }
  }

  // ============================================================================
  // POLLING MANAGEMENT
  // ============================================================================

  void _startPolling() {
    _stopPolling();
    _reportPoller = Timer.periodic(_pollInterval, (_) {
      if (mounted && _showReportMarkersAtCurrentZoom) _fetchReports();
    });
  }

  void _stopPolling() => _reportPoller?.cancel();

  void _manageUserPolling() {
    if (_canViewOtherUsers()) {
      _usersLocationCubit.startUsersPolling();
    } else {
      _usersLocationCubit.stopUsersPolling();
    }
  }

  void _manageAssignmentPolling() {
    // Only poll assignments for responders and coordinators
    if (widget.userType == UserType.responder ||
        widget.userType == UserType.coordinator) {
      _assignmentsCubit.startPolling();
    } else {
      _assignmentsCubit.stopPolling();
    }
  }

  // ============================================================================
  // FILTERING AND SEARCH
  // ============================================================================

  void _applyFiltersAndSearch() {
    List<ReportEntity> filtered = List.from(_cachedReports);

    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((r) =>
              r.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              r.description
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ||
              r.fullAddress.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }
    if (_selectedCategory != null) {
      filtered = filtered
          .where((r) =>
              (r.state?.emergencyType ?? '').toLowerCase() ==
              _selectedCategory!.toLowerCase())
          .toList();
    }
    if (_selectedStatus != null) {
      filtered = filtered
          .where((r) =>
              (r.state?.status ?? 'pending').toLowerCase() ==
              _selectedStatus!.toLowerCase())
          .toList();
    }

    filtered.sort((a, b) {
      int comparison = 0;
      switch (_sortBy) {
        case "priority":
          comparison =
              (b.state?.severity ?? 0.0).compareTo(a.state?.severity ?? 0.0);
          break;
        case "distance":
          comparison = calculateDistance(
                  _currentPosition, LatLng(a.latitude, a.longitude))
              .compareTo(calculateDistance(
                  _currentPosition, LatLng(b.latitude, b.longitude)));
          break;
        default:
          comparison = b.createdAt.compareTo(a.createdAt);
      }
      return _sortAscending ? comparison : -comparison;
    });

    setState(() => _filteredReports = filtered);
  }

  void _onSortSelected(String value) {
    setState(() {
      if (value == _sortBy) {
        _sortAscending = !_sortAscending;
      } else {
        _sortBy = value;
        _sortAscending = value == 'distance' ? true : false;
      }
    });
    _applyFiltersAndSearch();
  }

  void _clearFilters() {
    setState(() {
      _searchQuery = "";
      _selectedCategory = null;
      _selectedStatus = null;
      _sortBy = "distance";
      _sortAscending = true;
    });
    _applyFiltersAndSearch();
  }

  // ============================================================================
  // ROUTING & NAVIGATION
  // ============================================================================

  Future<void> _getAndDisplayRoute(ReportEntity report) async {
    if (!mounted || _isRouteLoading) return;
    setState(() {
      _isRouteLoading = true;
      _routePolyline = [];
    });
    try {
      final routeResult = await RoutingService.getRoute(
          _currentPosition, LatLng(report.latitude, report.longitude));
      if (routeResult.isValid && mounted) {
        setState(() => _routePolyline = routeResult.geometry);
        _mapController.fitCamera(CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(_routePolyline),
          padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 60.0),
        ));
      } else {
        _showErrorSnackBar(
            routeResult.errorMessage ?? 'Could not find a valid route');
      }
    } catch (e) {
      _showErrorSnackBar(
          e is RoutingException ? e.message : 'Failed to get directions.');
    } finally {
      if (mounted) setState(() => _isRouteLoading = false);
    }
  }

  void _clearRoute() {
    if (mounted) setState(() => _routePolyline = []);
    _showSuccessSnackBar("Route cleared");
  }

  // ============================================================================
  // PERMISSIONS & CONFIG
  // ============================================================================

  bool _canPerformResponderActions() =>
      widget.userType == UserType.responder ||
      widget.userType == UserType.coordinator;

  bool _canAccessReportChat(ReportEntity report) {
    final uid = context.read<AuthCubit>().userId;
    if (uid == null) return false;
    if (widget.userType == UserType.coordinator) return true;
    if (widget.userType == UserType.citizen) return report.initiatorId == uid;
    if (widget.userType == UserType.responder)
      return report.initiatorId == uid ||
          report.state?.assigned == uid ||
          _activeAssignment?.id == report.id;
    return false;
  }

  bool _canViewOtherUsers() =>
      (widget.userType == UserType.coordinator && _enableCoordinatorUserPolling) ||
      (widget.userType == UserType.responder && _enableResponderUserPolling);

  bool _shouldShowUserMarkers() {
    // debugPrint("=== USER MARKERS VISIBILITY CHECK ===");
    // debugPrint("User type: ${widget.userType}");
    // debugPrint("Coordinator polling enabled: $_enableCoordinatorUserPolling");
    // debugPrint("Responder polling enabled: $_enableResponderUserPolling");
    // debugPrint("Show user markers at current zoom: $_showUserMarkersAtCurrentZoom");
    // debugPrint("Active assignment: ${_activeAssignment != null ? 'YES (${_activeAssignment!.id})' : 'NO'}");
    
    bool result = false;
    
    // Coordinators see user markers at appropriate zoom level (when feature enabled)
    if (widget.userType == UserType.coordinator) {
      result = _enableCoordinatorUserPolling && _showUserMarkersAtCurrentZoom;
    //  debugPrint("Coordinator result: $result (polling=$_enableCoordinatorUserPolling && zoom=$_showUserMarkersAtCurrentZoom)");
    }
    // Responders only see user markers when assigned, at appropriate zoom level, and feature enabled
    else if (widget.userType == UserType.responder) {
      result = _enableResponderUserPolling && 
               _activeAssignment != null && 
               _showUserMarkersAtCurrentZoom;
      //debugPrint("Responder result: $result (polling=$_enableResponderUserPolling && assigned=${_activeAssignment != null} && zoom=$_showUserMarkersAtCurrentZoom)");
    }
    // Citizens don't see other users
    else {
      result = false;
     // debugPrint("Citizen result: false");
    }
    
   // debugPrint("Final shouldShowUserMarkers: $result");
    return result;
  }

  // ============================================================================
  // ZOOM & VISIBILITY HELPERS
  // ============================================================================

  void _updateZoomBasedVisibility(double zoom) {
    bool needsRebuild = false;
    final shouldShowReports = zoom >= _minZoomForReportMarkers;
    final shouldShowUsers = zoom >= _minZoomForUserMarkers;
    
    // debugPrint("=== UPDATING ZOOM-BASED VISIBILITY ===");
    // debugPrint("Current zoom: $zoom");
    // debugPrint("Min zoom for reports: $_minZoomForReportMarkers");
    // debugPrint("Min zoom for users: $_minZoomForUserMarkers");
    // debugPrint("Should show reports: $shouldShowReports");
    // debugPrint("Should show users: $shouldShowUsers");
    
    if (_showReportMarkersAtCurrentZoom != shouldShowReports) {
      _showReportMarkersAtCurrentZoom = shouldShowReports;
      needsRebuild = true;
      //debugPrint("Updated _showReportMarkersAtCurrentZoom: $shouldShowReports");
    }
    if (_showUserMarkersAtCurrentZoom != shouldShowUsers) {
      _showUserMarkersAtCurrentZoom = shouldShowUsers;
      needsRebuild = true;
     // debugPrint("Updated _showUserMarkersAtCurrentZoom: $shouldShowUsers");
    }
    
    if (needsRebuild) {
      // debugPrint("Triggering setState for zoom visibility update");
      setState(() {});
    }
  }

  // ============================================================================
  // EVENT HANDLERS & UI TRIGGERS
  // ============================================================================

  void _onMapPositionChanged(MapCamera camera, bool hasGesture) {
    if (hasGesture) {
      _updateZoomBasedVisibility(camera.zoom);
      
      // For coordinators, keep polling always active (never stop)
      if (widget.userType == UserType.coordinator && _enableCoordinatorUserPolling) {
        _startPolling(); // Always poll for coordinators
      } else {
        // For other users, use zoom-based polling
        if (_showReportMarkersAtCurrentZoom)
          _startPolling();
        else
          _stopPolling();
      }
    }
  }

  void _showReportDetails(ReportEntity report) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReportDetailsSheet(
        report: report,
        currentPosition: _currentPosition,
        onLocateOnMap: _locateReportOnMap,
        onAssignToSelf: _assignToSelf,
        onGetDirections: _getAndDisplayRoute,
        onChat: _canAccessReportChat(report) ? _navigateToReportChat : null,
        userType: widget.userType,
        availableResponders: _otherUsers,
        assignmentsCubit: _assignmentsCubit,
        currentUserId: context.read<AuthCubit>().userId,
        onCloseReport: (report) {
      context
          .read<ReportsCubit>()
          .updateReportStatus(report.id, 'closed');
    },
        onDeleteReport: (report){

context
              .read<ReportsCubit>()
              .updateReportStatus(report.id, 'deleted');
        },
      
      ),
    );
  }

  void _showUserDetails(UserLocationEntity user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UserDetailsSheet(user: user),
    );
  }

  void _navigateToEmergencyChat() {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const AIEmergencyChatScreen()));
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
                    participants: const [],
                  ),
                )));
  }

  Future<void> _centerMapOnCurrentLocation() async {
    if (_isLocationLoading) return;
    _mapController.move(_currentPosition, 20.0);
    await _fetchReports();
  }

  void _locateReportOnMap(ReportEntity report, {double? zoom}) {
    _tabController.animateTo(0);
    final targetZoom = zoom ?? 17.0; // Use higher default zoom for reports
    _mapController.move(
        LatLng(report.latitude, report.longitude), targetZoom);
    _showSuccessSnackBar("Report located on map");
  }

  void _centerMapOnReportId(int reportId, {double zoom = 17.0}) {
    final report = _cachedReports.where((r) => r.id == reportId).firstOrNull;
    if (report != null) {
      _locateReportOnMap(report, zoom: zoom);
    } else {
      _showErrorSnackBar("Report not found. Refreshing reports...");
      _handleManualRefresh();
    }
  }

  void _onMapReady() {
    // Notify MapNavigationService that map is ready
    MapNavigationService().setMapReady();
  }

  // ============================================================================
  // UNIFIED DASHBOARD ACTIONS INTERFACE
  // ============================================================================

  @override
  ReportEntity? getCachedReport(int reportId) {
    return _cachedReports.where((r) => r.id == reportId).firstOrNull;
  }

  @override
  void showReportDetails(ReportEntity report) {
    _showReportDetails(report);
  }

  Future<void> _updateAssignmentStatus(String status) async {
    if (_activeAssignment == null) return;
    try {
    //  debugPrint("Updating assignment status to: $status");
      // TODO: Implement API call
      _showSuccessSnackBar("Status updated: ${status.replaceAll('_', ' ')}");
    } catch (e) {
      _showErrorSnackBar("Failed to update status");
    }
  }

  Future<void> _assignToSelf(ReportEntity report) async {
    try {
      debugPrint("Assigning report ${report.id} to current user");
      // TODO: Implement API call
      setState(() => _activeAssignment = report);
      _showSuccessSnackBar("Report assigned successfully");
      _manageUserPolling();
      _tabController.animateTo(0);
    } catch (e) {
      _showErrorSnackBar("Failed to assign report");
    }
  }

  void _navigateToFocusMode(ParticipationRequest activeAssignment) {
    debugPrint('🎯 [FOCUS_MODE] ========== NAVIGATION TO FOCUS MODE ==========');
    debugPrint('🎯 [FOCUS_MODE] Assignment ID: ${activeAssignment.id}');
    debugPrint('🎯 [FOCUS_MODE] Report ID: ${activeAssignment.report.id}');
    debugPrint('🎯 [FOCUS_MODE] Current position: $_currentPosition');
    
    // Get the full report data from cached reports
    final fullReport = _getEnhancedReportData(activeAssignment);
    if (fullReport == null) {
      debugPrint('🚨 [FOCUS_MODE] ❌ Cannot navigate: full report data not found in cache');
      _showErrorSnackBar('خطأ: لم يتم العثور على بيانات البلاغ كاملة');
      return;
    }
    
    debugPrint('🎯 [FOCUS_MODE] ✅ Full report data retrieved for report ${fullReport.id}');
    debugPrint('🎯 [FOCUS_MODE] Report location: ${fullReport.latitude}, ${fullReport.longitude}');
    debugPrint('🎯 [FOCUS_MODE] Report name: ${fullReport.state?.report?.name ?? "Unknown"}');
    debugPrint('🎯 [FOCUS_MODE] Emergency type: ${fullReport.state?.emergencyType ?? "Unknown"}');
    debugPrint('🎯 [FOCUS_MODE] Creating MultiBlocProvider...');
    
    try {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) {
            debugPrint('🎯 [FOCUS_MODE] Building FocusModeScreen with full report data...');
            return MultiBlocProvider(
              providers: [
                BlocProvider.value(value: context.read<ChatCubit>()),
                BlocProvider.value(value: context.read<UsersLocationCubit>()),
                BlocProvider.value(value: context.read<AuthCubit>()),
              ],
              child: FocusModeScreen(
                activeAssignment: activeAssignment,
                fullReport: fullReport,           // Pass the complete report data
                currentPosition: _currentPosition,
              ),
            );
          },
        ),
      );
      debugPrint('🎯 [FOCUS_MODE] ✅ Navigation to focus mode initiated with full report data');
    } catch (e, stackTrace) {
      debugPrint('🚨 [FOCUS_MODE] Navigation error: $e');
      debugPrint('🚨 [FOCUS_MODE] Navigation stack trace: $stackTrace');
    }
  }

  // ============================================================================
  // ASSIGNMENT NOTIFICATION MANAGEMENT
  // ============================================================================

  void _dismissAssignmentNotification() {
    if (mounted) {
      setState(() {
        _pendingAssignmentRequest = null;
        _isAssignmentNotificationVisible = false;
        _isProcessingAssignmentAction = false;
      });
    }
  }

  Future<void> _acceptAssignmentRequest() async {
    if (_pendingAssignmentRequest == null || _isProcessingAssignmentAction)
      return;

    setState(() => _isProcessingAssignmentAction = true);

    try {
      await _assignmentsCubit.acceptParticipationRequest(
        requestId: _pendingAssignmentRequest!.id,
      );
    } catch (e) {
      _showErrorSnackBar("Failed to accept assignment: ${e.toString()}");
      setState(() => _isProcessingAssignmentAction = false);
    }
  }

  Future<void> _rejectAssignmentRequest() async {
    if (_pendingAssignmentRequest == null || _isProcessingAssignmentAction)
      return;

    setState(() => _isProcessingAssignmentAction = true);

    try {
      await _assignmentsCubit.rejectParticipationRequest(
        requestId: _pendingAssignmentRequest!.id,
      );
    } catch (e) {
      _showErrorSnackBar("Failed to reject assignment: ${e.toString()}");
      setState(() => _isProcessingAssignmentAction = false);
    }
  }

  // ============================================================================
  // SNACKBARS & CLEANUP
  // ============================================================================

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline, color: Colors.white),
        const SizedBox(width: 8),
        Expanded(child: Text(message))
      ]),
      backgroundColor: Colors.red.shade600,
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle, color: Colors.white),
        const SizedBox(width: 8),
        Expanded(child: Text(message))
      ]),
      backgroundColor: Colors.green.shade600,
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _cleanup() {
    _stopPolling();
    _usersLocationCubit.stopUsersPolling();
    _usersLocationCubit.stopLocationPolling();
    _assignmentsCubit.stopPolling();
    _tabController.dispose();
  }

  // ============================================================================
  // BUILD METHOD & UI STRUCTURE
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          BlocListener<AssignmentsCubit, AssignmentsState>(
            listener: _handleAssignmentsStateChange,
            child: _buildBody(),
          ),
          // Emergency assignment notification overlay
          if (_isAssignmentNotificationVisible &&
              _pendingAssignmentRequest != null)
            _buildAssignmentNotificationOverlay(),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigation(),
      floatingActionButton:
          widget.userType == UserType.citizen ? _buildCitizenFAB() : null,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    String title;
    switch (widget.userType) {
      case UserType.citizen:
        title = 'SafetyConnect';
        break;
      case UserType.responder:
        title = 'Emergency Response';
        break;
      case UserType.coordinator:
        title = 'Emergency Operations';
        break;
    }
    return AppBar(
      title: Text(title),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      actions: [
        //MockRequestButton(),
        if (_networkError != null)
          IconButton(
            icon: Icon(Icons.signal_wifi_off, color: Colors.orange[700]),
            onPressed: () {
              _handleManualRefresh;
            },
            tooltip: 'Connection Issues - Tap to Retry',
          ),
        if (_activeAssignment != null && _canPerformResponderActions())
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: Colors.blue.shade600,
                borderRadius: BorderRadius.circular(12)),
            child: const Text('ACTIVE',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
          ),
        IconButton(
          icon: const Icon(Icons.person_outline),
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ProfileScreen())),
          tooltip: 'Profile',
        ),
      ],
    );
  }

  Widget _buildBody() {
    return MultiBlocListener(
      listeners: [
        BlocListener<ReportsCubit, ReportsState>(
            listener: _handleReportsStateChange),
        BlocListener<UsersLocationCubit, UsersLocationState>(
            listener: _handleUsersLocationStateChange),
      ],
      child: _isInitializing
          ? _buildInitializationScreen()
          : TabBarView(controller: _tabController, children: _getTabViews()),
    );
  }

  List<Widget> _getTabViews() {
    return [
      // MAP TAB
      MapTabView(
        mapController: _mapController,
        userType: widget.userType,
        activeAssignment: _activeAssignment,
        currentPosition: _currentPosition,
        routePolyline: _routePolyline,
        reports: _filteredReports,
        otherUsers: _otherUsers,
        isRouteLoading: _isRouteLoading,
        isRefreshing: _isRefreshing,
        showReportMarkers: _showReportMarkersAtCurrentZoom,
        showUserMarkers: _shouldShowUserMarkers(),
        defaultZoom: _defaultZoom,
        onPositionChanged: _onMapPositionChanged,
        onRefresh: _handleManualRefresh,
        onCenterMap: _centerMapOnCurrentLocation,
        onShowFilters: () {}, // TODO: Implement map filters
        onShowReportDetails: _showReportDetails,
        onShowUserDetails: _showUserDetails,
        onGetDirections: _getAndDisplayRoute,
        onClearRoute: _clearRoute,
        onUpdateAssignmentStatus: _updateAssignmentStatus,
        onMapReady: _onMapReady,
      ),
      // REPORTS TAB
      ReportsTabView(
        reports: _filteredReports,
        activeAssignment: _activeAssignment,
        currentPosition: _currentPosition,
        searchQuery: _searchQuery,
        selectedCategory: _selectedCategory,
        selectedStatus: _selectedStatus,
        sortBy: _sortBy,
        sortAscending: _sortAscending,
        isRefreshing: _isRefreshing,
        lastSuccessfulRefresh: _lastSuccessfulRefresh,
        networkError: _networkError,
        userType: widget.userType,
        onRefresh: _handleManualRefresh,
        onSearchChanged: (q) {
          setState(() => _searchQuery = q);
          _applyFiltersAndSearch();
        },
        onCategorySelected: (c) {
          setState(() => _selectedCategory = c == "All" ? null : c);
          _applyFiltersAndSearch();
        },
        onStatusSelected: (s) {
          setState(() => _selectedStatus = s == "All" ? null : s);
          _applyFiltersAndSearch();
        },
        onSortSelected: _onSortSelected,
        onClearFilters: _clearFilters,
        onReportTap: _showReportDetails,
        onLocateOnMap: _locateReportOnMap,
        onChat: _navigateToReportChat,
      ),
      // CHAT TAB
      context.read<AuthCubit>().isAuthenticated
          ? const ChatsListScreen()
          : _buildAuthRequiredMessage(),
    ];
  }

  Widget _buildBottomNavigation() {
    return Material(
      elevation: 8,
      child: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(icon: Icon(Icons.map_outlined), text: 'Map'),
          Tab(icon: Icon(Icons.report_outlined), text: 'Reports'),
          Tab(icon: Icon(Icons.chat_outlined), text: 'Chat'),
        ],
        labelColor: Theme.of(context).primaryColor,
        unselectedLabelColor: Colors.grey[600],
        indicatorColor: Theme.of(context).primaryColor,
        indicatorWeight: 3,
      ),
    );
  }

  Widget _buildInitializationScreen() {
    return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      CircularProgressIndicator(color: Theme.of(context).primaryColor),
      const SizedBox(height: 24),
      Text('Initializing SafetyConnect...',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700])),
      const SizedBox(height: 8),
      Text('Setting up your emergency dashboard',
          style: TextStyle(fontSize: 14, color: Colors.grey[500])),
    ]));
  }

  Widget _buildCitizenFAB() {
    return FloatingActionButton(
      onPressed: _navigateToEmergencyChat,
      backgroundColor: Colors.red,
      foregroundColor: Colors.white,
      elevation: 8,
      child: Container(
        width: 48,
        height: 48,
        decoration:
            const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: const Text('🚨', style: TextStyle(fontSize: 24)),
      ),
    );
  }

  Widget _buildAuthRequiredMessage() {
    return Center(
        child: Padding(
            padding: const EdgeInsets.all(24),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.chat_outlined, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text('Authentication Required',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text('Please sign in to access chat features.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey[600])),
            ])));
  }

  // ============================================================================
  // ENHANCED REPORT DATA RETRIEVAL
  // ============================================================================
  
  /// Retrieves comprehensive report data by merging participation request with cached reports
  ReportEntity? _getEnhancedReportData(ParticipationRequest request) {
    if (request.report?.id == null) return null;
    
    try {
      // Find the full report in cached reports using the report ID
      final reportId = request.report.id;
      final cachedReport = _cachedReports.where((r) => r.id == reportId).firstOrNull;
      
      if (cachedReport != null) {
        debugPrint('🚨 [ASSIGNMENT_POPUP] Found enhanced report data for report $reportId');
        return cachedReport;
      } else {
        debugPrint('🚨 [ASSIGNMENT_POPUP] Report $reportId not found in cache, using basic data');
        return null;
      }
    } catch (e) {
      debugPrint('🚨 [ASSIGNMENT_POPUP] Error retrieving enhanced report data: $e');
      return null;
    }
  }
  
  /// Gets emergency type icon based on emergency type
  IconData _getEmergencyTypeIcon(String? emergencyType) {
    switch (emergencyType?.toLowerCase()) {
      case 'medical':
        return Icons.medical_services;
      case 'fire':
        return Icons.local_fire_department;
      case 'police':
        return Icons.local_police;
      case 'traffic':
        return Icons.traffic;
      case 'civil':
        return Icons.engineering;
      default:
        return Icons.emergency;
    }
  }
  
  /// Gets emergency type color based on emergency type
  Color _getEmergencyTypeColor(String? emergencyType) {
    switch (emergencyType?.toLowerCase()) {
      case 'medical':
        return Colors.red.shade600;
      case 'fire':
        return Colors.orange.shade600;
      case 'police':
        return Colors.blue.shade600;
      case 'traffic':
        return Colors.amber.shade600;
      case 'civil':
        return Colors.purple.shade600;
      default:
        return Colors.grey.shade600;
    }
  }
  
  /// Gets severity color based on severity level (0.0-1.0)
  Color _getSeverityColor(double? severity) {
    if (severity == null) return Colors.grey.shade600;
    if (severity >= 0.8) return Colors.red.shade700;
    if (severity >= 0.6) return Colors.orange.shade600;
    if (severity >= 0.4) return Colors.yellow.shade600;
    return Colors.green.shade600;
  }
  
  /// Gets severity label based on severity level
  String _getSeverityLabel(double? severity) {
    if (severity == null) return 'غير محدد';
    if (severity >= 0.8) return 'حرج جداً';
    if (severity >= 0.6) return 'عاجل';
    if (severity >= 0.4) return 'متوسط';
    return 'عادي';
  }
  
  /// Formats elapsed time since report creation
  String _getElapsedTime(DateTime createdAt) {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    
    if (difference.inMinutes < 1) {
      return 'للتو';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} دقيقة';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} ساعة';
    } else {
      return '${difference.inDays} يوم';
    }
  }
  
  /// Gets display name for emergency type in Arabic
  String _getEmergencyTypeDisplayName(String emergencyType) {
    switch (emergencyType.toLowerCase()) {
      case 'medical':
        return 'طبي';
      case 'fire':
        return 'حريق';
      case 'police':
        return 'أمني';
      case 'traffic':
        return 'مروري';
      case 'civil':
        return 'مدني';
      default:
        return 'طوارئ عامة';
    }
  }
  
  /// Gets user display name from user ID (for initiator display)
  String? _getUserDisplayName(int userId) {
    try {
      // Try to find user in cached other users list
      final user = _otherUsers.where((u) => u.id == userId).firstOrNull;
      return user?.name;
    } catch (e) {
      debugPrint('🚨 [ASSIGNMENT_POPUP] Error getting user display name: $e');
      return null;
    }
  }

  // ============================================================================
  // EMERGENCY ASSIGNMENT NOTIFICATION OVERLAY
  // ============================================================================

  Widget _buildAssignmentNotificationOverlay() {
    final request = _pendingAssignmentRequest!;
    final basicReport = request.report;
    final enhancedReport = _getEnhancedReportData(request);

    // Use enhanced report data if available, fallback to basic
    final report = enhancedReport ?? basicReport;
    final emergencyType = enhancedReport?.state?.emergencyType;
    final severity = enhancedReport?.state?.severity;
    final reportName = enhancedReport?.state?.report?.name;
    final reportDescription = enhancedReport?.state?.report?.description ?? enhancedReport?.state?.report?.text;
    
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 500),
      curve: Curves.elasticOut,
      top: _isAssignmentNotificationVisible ? 0 : -300,
      left: 0,
      right: 0,
      child: Container(
        margin: const EdgeInsets.all(16),
        constraints: const BoxConstraints(maxHeight: 600), // Limit height for scrolling
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _getEmergencyTypeColor(emergencyType),
              _getEmergencyTypeColor(emergencyType).withOpacity(0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: _getEmergencyTypeColor(emergencyType).withOpacity(0.4),
              blurRadius: 25,
              spreadRadius: 3,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Enhanced Header with emergency type
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          _getEmergencyTypeIcon(emergencyType),
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '🚨 مهمة طوارئ جديدة',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (emergencyType != null)
                              Text(
                                _getEmergencyTypeDisplayName(emergencyType),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            Text(
                              'طلب رقم #${request.id}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _dismissAssignmentNotification,
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Emergency Classification Section
                  if (severity != null || emergencyType != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.priority_high,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'تصنيف الطوارئ',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (severity != null)
                            Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: _getSeverityColor(severity),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'مستوى الخطورة: ${_getSeverityLabel(severity)}',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '(${(severity * 100).toInt()}%)',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          if (enhancedReport?.state?.emergencySubType != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.category,
                                  color: Colors.white.withOpacity(0.8),
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'النوع الفرعي: ${enhancedReport!.state!.emergencySubType}',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Report Details Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Report Name or ID
                        Row(
                          children: [
                            Icon(
                              Icons.report_problem,
                              color: Colors.amber.shade300,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                reportName ?? 'بلاغ طوارئ #${basicReport.id}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (enhancedReport?.latestStatus != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getReportStatusBackgroundColor(
                                    enhancedReport!.latestStatus!.statusColor,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  enhancedReport.latestStatus!.statusDisplay,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),

                        // Report description if available
                        if (reportDescription != null && reportDescription.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              reportDescription,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 12),

                        // People involved
                        Row(
                          children: [
                            Icon(
                              Icons.person,
                              color: Colors.white.withOpacity(0.8),
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'مُبلغ من: ${(enhancedReport != null ? _getUserDisplayName(enhancedReport.initiatorId) : basicReport.initiator?.name) ?? 'غير معروف'}',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        Row(
                          children: [
                            Icon(
                              Icons.assignment_ind,
                              color: Colors.white.withOpacity(0.8),
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'مُكلف من: ${request.initiator.name}',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Timing information
                        if (enhancedReport != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                color: Colors.white.withOpacity(0.8),
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'منذ: ${_getElapsedTime(enhancedReport.createdAt)}',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 14,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${enhancedReport.formattedTime} - ${enhancedReport.formattedDate}',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Location and Distance Section
                  if (enhancedReport != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                color: Colors.red.shade300,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'معلومات الموقع',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            enhancedReport.fullAddress,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.gps_fixed,
                                color: Colors.white.withOpacity(0.8),
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${enhancedReport.latitude.toStringAsFixed(4)}, ${enhancedReport.longitude.toStringAsFixed(4)}',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 12,
                                ),
                              ),
                              if (enhancedReport.distance != null) ...[
                                const Spacer(),
                                Icon(
                                  Icons.straighten,
                                  color: Colors.white.withOpacity(0.8),
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  enhancedReport.distance!,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Status notes if available
                  if (enhancedReport?.latestStatus?.notes != null && enhancedReport!.latestStatus!.notes!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.note_alt,
                                color: Colors.white.withOpacity(0.8),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'ملاحظات إضافية',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            enhancedReport.latestStatus!.notes!,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                const SizedBox(height: 24),

                // Enhanced Action buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isProcessingAssignmentAction
                            ? null
                            : _acceptAssignmentRequest,
                        icon: _isProcessingAssignmentAction
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Icon(Icons.check_circle, color: Colors.white, size: 20),
                        label: const Text(
                          'قبول المهمة',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 8,
                          shadowColor: Colors.green.withOpacity(0.4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isProcessingAssignmentAction
                            ? null
                            : _rejectAssignmentRequest,
                        icon: const Icon(Icons.cancel_outlined, color: Colors.white, size: 20),
                        label: const Text(
                          'رفض المهمة',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white, width: 2),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          backgroundColor: Colors.white.withOpacity(0.1),
                        ),
                      ),
                    ),
                  ],
                ),
                
                // Additional information message
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.white.withOpacity(0.8),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'قبول المهمة سينقلك تلقائياً إلى وضع التركيز مع التنقل GPS',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    )
    );
  }

  Color _getReportStatusBackgroundColor(String statusColor) {
    switch (statusColor.toLowerCase()) {
      case 'blue':
        return Colors.blue.shade600;
      case 'red':
        return Colors.red.shade600;
      case 'green':
        return Colors.green.shade600;
      case 'orange':
        return Colors.orange.shade600;
      default:
        return Colors.grey.shade600;
    }
  }
}
