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
import 'package:emergency_map_sy/features/reports/models/report.dart'
    hide ParticipationRequest;
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

/// لوحة تحكم موحدة تتكيف واجهتها بناءً على نوع المستخدم.
/// تقوم هذه الويدجت بإدارة الحالة ومنطق العمل، وتفوض مهمة عرض الواجهة
/// إلى ويدجت عرض متخصصة.
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
  // --- إدارة الحالة (STATE MANAGEMENT) ---
  final MapController _mapController = MapController();
  late TabController _tabController;
  Timer? _reportPoller;
  late UsersLocationCubit _usersLocationCubit;
  late AssignmentsCubit _assignmentsCubit;

  // --- حالة الموقع والبيانات (LOCATION & DATA STATE) ---
  LatLng _currentPosition = const LatLng(33.5138, 36.2765); // دمشق افتراضي
  String _currentAddress = "جاري الحصول على الموقع...";
  List<ReportEntity> _cachedReports = [];
  List<ReportEntity> _filteredReports = [];
  ReportEntity? _activeAssignment;
  DateTime? _lastSuccessfulRefresh;
  List<UserLocationEntity> _otherUsers = [];

  // --- حالة الفلترة والبحث (FILTER & SEARCH STATE) ---
  String _searchQuery = "";
  String? _selectedCategory;
  String? _selectedStatus;
  String _sortBy = "distance";
  bool _sortAscending = true;

  // --- حالة واجهة المستخدم (UI STATE) ---
  bool _isInitializing = true;
  bool _isLocationLoading = false;
  bool _isRefreshing = false;
  String? _locationError;
  String? _networkError;
  List<LatLng> _routePolyline = [];
  bool _isRouteLoading = false;
  bool _showReportMarkersAtCurrentZoom = true;
  bool _showUserMarkersAtCurrentZoom = false;

  // --- حالة إشعارات المهام (ASSIGNMENT NOTIFICATION STATE) ---
  ParticipationRequest? _pendingAssignmentRequest;
  bool _isAssignmentNotificationVisible = false;
  bool _isProcessingAssignmentAction = false;

  // --- الإعدادات (CONFIGURATION) ---
  static const Duration _pollInterval = Duration(seconds: 5);
  static const Duration _networkTimeout = Duration(seconds: 5);
  static const double _defaultZoom = 14.0;
  static const double _minZoomForReportMarkers = 8.0;
  static const double _minZoomForUserMarkers = 14.0;

  static const bool _enableCoordinatorUserPolling = true;
  static const bool _enableResponderUserPolling = false;
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

    if (widget.userType == UserType.responder) {
      debugPrint('🚨 [DASHBOARD_INIT] تهيئة التحقق من المهام للمستجيب');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _assignmentsCubit.loadAllAssignments();
      });
    }
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
      debugPrint(
          '🚨 [DASHBOARD_LIFECYCLE] التطبيق استؤنف - إعادة تشغيل التحقق');
      _startPolling();
      _manageUserPolling();
      _manageAssignmentPolling();

      if (widget.userType == UserType.responder) {
        debugPrint(
            '🚨 [DASHBOARD_LIFECYCLE] إعادة تحميل المهام للمستجيب عند الاستئناف');
        _assignmentsCubit.loadAllAssignments();
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      debugPrint(
          '🚨 [DASHBOARD_LIFECYCLE] التطبيق متوقف مؤقتاً - إيقاف التحقق');
      _stopPolling();
      _usersLocationCubit.stopUsersPolling();
      _assignmentsCubit.stopPolling();
    }
  }

  // ============================================================================
  // التهيئة (INITIALIZATION)
  // ============================================================================

  Future<void> _initializeApp() async {
    try {
      await context.read<AuthCubit>().waitForInitialization();
      await _initializeLocation();
      await _fetchReports();

      _updateZoomBasedVisibility(_defaultZoom);

      _startPolling();
      _manageUserPolling();
      _manageAssignmentPolling();
    } catch (e) {
      debugPrint("خطأ في التهيئة: $e");
      if (mounted) setState(() => _networkError = "فشل في تهيئة التطبيق");
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
      if (!serviceEnabled) throw const LocationException('خدمات الموقع معطلة');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied)
        permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw const LocationException('تم رفض إذن الوصول للموقع');
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
  // جلب البيانات ومعالجة الحالة (DATA FETCHING & STATE HANDLING)
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
        setState(() => _networkError = "غير قادر على جلب آخر التحديثات");
    }
  }

  Future<void> _handleManualRefresh() async {
    if (!mounted || _isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      await _fetchReports();
      if (_canViewOtherUsers()) await _usersLocationCubit.fetchUsersLocations();
      await _initializeLocation();
      _showSuccessSnackBar("تم تحديث البلاغات والموقع بنجاح");
    } catch (e) {
      _showErrorSnackBar("فشل في تحديث البيانات");
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
      });
      if (previousAssignmentStatus != (_activeAssignment != null)) {
        _manageUserPolling();
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
    debugPrint("=== تغير حالة مواقع المستخدمين ===");
    if (state is UsersLocationSuccess) {
      setState(() => _otherUsers = state.users);
    } else if (state is UsersLocationError) {
      debugPrint("خطأ في جلب مواقع المستخدمين: ${state.message}");
    }
  }

  void _handleAssignmentsStateChange(
      BuildContext context, AssignmentsState state) {
    if (!mounted) return;

    if (state is AssignedMode && widget.userType == UserType.responder) {
      debugPrint('🎯 [FOCUS_MODE] تم الكشف عن وضع المهمة في UnifiedDashboard');
      debugPrint(
          '🎯 [FOCUS_MODE] رقم البلاغ: ${state.activeAssignment.report.id}');
      debugPrint('🎯 [FOCUS_MODE] أول مرة للمهمة: ${state.isFirstTime}');
      debugPrint(
          '🎯 [FOCUS_MODE] حالة المهمة: ${state.activeAssignment.status}');

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
              debugPrint(
                  '🎯 [FOCUS_MODE] المستخدم قام بالنقر على الإشعار لعرض المهمة');
              debugPrint('🎯 [FOCUS_MODE] جاري الانتقال إلى وضع التركيز...');
              _navigateToFocusMode(state.activeAssignment);
            },
          ),
        ),
      );
      return;
    }

    if (state is AssignmentsLoaded && widget.userType == UserType.responder) {
      final pendingRequests = state.pendingRequests;
      if (pendingRequests.isNotEmpty && !_isAssignmentNotificationVisible) {
        final newRequest = pendingRequests.first;
        setState(() {
          _pendingAssignmentRequest = newRequest;
          _isAssignmentNotificationVisible = true;
        });
      } else if (pendingRequests.isEmpty && _isAssignmentNotificationVisible) {
        _dismissAssignmentNotification();
      }
    } else if (state is AssignmentActionSuccess) {
      _showSuccessSnackBar(state.message);
      if (state.action == 'accept') {
        _dismissAssignmentNotification();
        if (state.updatedRequest != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _navigateToFocusMode(state.updatedRequest!);
          });
        }
      } else if (state.action == 'reject') {
        _dismissAssignmentNotification();
      }
    } else if (state is AssignmentsError) {
      _showErrorSnackBar("خطأ في المهمة: ${state.message}");
    }
  }

  // ============================================================================
  // إدارة التحقق (POLLING MANAGEMENT)
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
    if (widget.userType == UserType.responder ||
        widget.userType == UserType.coordinator) {
      _assignmentsCubit.startPolling();
    } else {
      _assignmentsCubit.stopPolling();
    }
  }

  // ============================================================================
  // الفلترة والبحث (FILTERING AND SEARCH)
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
  // التوجيه والملاحة (ROUTING & NAVIGATION)
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
            routeResult.errorMessage ?? 'لم يتم العثور على مسار صالح');
      }
    } catch (e) {
      _showErrorSnackBar(
          e is RoutingException ? e.message : 'فشل في الحصول على الاتجاهات.');
    } finally {
      if (mounted) setState(() => _isRouteLoading = false);
    }
  }

  void _clearRoute() {
    if (mounted) setState(() => _routePolyline = []);
    _showSuccessSnackBar("تم مسح المسار");
  }

  // ============================================================================
  // الأذونات والإعدادات (PERMISSIONS & CONFIG)
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
      (widget.userType == UserType.coordinator &&
          _enableCoordinatorUserPolling) ||
      (widget.userType == UserType.responder && _enableResponderUserPolling);

  bool _shouldShowUserMarkers() {
    bool result = false;

    if (widget.userType == UserType.coordinator) {
      result = _enableCoordinatorUserPolling && _showUserMarkersAtCurrentZoom;
    } else if (widget.userType == UserType.responder) {
      result = _enableResponderUserPolling &&
          _activeAssignment != null &&
          _showUserMarkersAtCurrentZoom;
    } else {
      result = false;
    }
    return result;
  }

  // ============================================================================
  // مساعدات التكبير والرؤية (ZOOM & VISIBILITY HELPERS)
  // ============================================================================

  void _updateZoomBasedVisibility(double zoom) {
    bool needsRebuild = false;
    final shouldShowReports = zoom >= _minZoomForReportMarkers;
    final shouldShowUsers = zoom >= _minZoomForUserMarkers;

    if (_showReportMarkersAtCurrentZoom != shouldShowReports) {
      _showReportMarkersAtCurrentZoom = shouldShowReports;
      needsRebuild = true;
    }
    if (_showUserMarkersAtCurrentZoom != shouldShowUsers) {
      _showUserMarkersAtCurrentZoom = shouldShowUsers;
      needsRebuild = true;
    }

    if (needsRebuild) {
      setState(() {});
    }
  }

  // ============================================================================
  // معالجات الأحداث ومحفزات واجهة المستخدم (EVENT HANDLERS & UI TRIGGERS)
  // ============================================================================

  void _onMapPositionChanged(MapCamera camera, bool hasGesture) {
    if (hasGesture) {
      _updateZoomBasedVisibility(camera.zoom);

      if (widget.userType == UserType.coordinator &&
          _enableCoordinatorUserPolling) {
        _startPolling();
      } else {
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
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: ReportDetailsSheet(
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
          onDeleteReport: (report) {
            context
                .read<ReportsCubit>()
                .updateReportStatus(report.id, 'deleted');
          },
        ),
      ),
    );
  }

  void _showUserDetails(UserLocationEntity user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: UserDetailsSheet(user: user),
      ),
    );
  }

  void _navigateToEmergencyChat() {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const AIEmergencyChatScreenAR()));
  }

  void _navigateToReportChat(ReportEntity report) {
    final conversationId = report.conversation?.id;
    if (conversationId == null) {
      _showErrorSnackBar("لا يوجد دردشة متاحة لهذا البلاغ");
      return;
    }
    final authCubit = context.read<AuthCubit>();
    if (!authCubit.isAuthenticated || authCubit.userId == null) {
      _showErrorSnackBar("يرجى تسجيل الدخول للوصول إلى الدردشة");
      return;
    }
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => BlocProvider.value(
                  value: context.read<ChatCubit>(),
                  child: ChatConversationScreen(
                    chatId: conversationId,
                    chatTitle: 'بلاغ طوارئ #${report.id}',
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
    final targetZoom = zoom ?? 17.0;
    _mapController.move(LatLng(report.latitude, report.longitude), targetZoom);
    _showSuccessSnackBar("تم تحديد موقع البلاغ على الخريطة");
  }

  void _centerMapOnReportId(int reportId, {double zoom = 17.0}) {
    final report = _cachedReports.where((r) => r.id == reportId).firstOrNull;
    if (report != null) {
      _locateReportOnMap(report, zoom: zoom);
    } else {
      _showErrorSnackBar("لم يتم العثور على البلاغ. جاري تحديث البلاغات...");
      _handleManualRefresh();
    }
  }

  void _onMapReady() {
    MapNavigationService().setMapReady();
  }

  // ============================================================================
  // واجهة إجراءات لوحة التحكم الموحدة (UNIFIED DASHBOARD ACTIONS INTERFACE)
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
      _showSuccessSnackBar("تم تحديث الحالة: ${status.replaceAll('_', ' ')}");
    } catch (e) {
      _showErrorSnackBar("فشل في تحديث الحالة");
    }
  }

  Future<void> _assignToSelf(ReportEntity report) async {
    try {
      debugPrint("جاري تعيين بلاغ ${report.id} للمستخدم الحالي");
      setState(() => _activeAssignment = report);
      _showSuccessSnackBar("تم تعيين البلاغ بنجاح");
      _manageUserPolling();
      _tabController.animateTo(0);
    } catch (e) {
      _showErrorSnackBar("فشل في تعيين البلاغ");
    }
  }

  void _navigateToFocusMode(ParticipationRequest activeAssignment) {
    debugPrint(
        '🎯 [FOCUS_MODE] ========== الانتقال إلى وضع التركيز ==========');
    debugPrint('🎯 [FOCUS_MODE] رقم المهمة: ${activeAssignment.id}');
    debugPrint('🎯 [FOCUS_MODE] رقم البلاغ: ${activeAssignment.report.id}');
    debugPrint('🎯 [FOCUS_MODE] الموقع الحالي: $_currentPosition');

    final fullReport = _getEnhancedReportData(activeAssignment);
    if (fullReport == null) {
      debugPrint(
          '🚨 [FOCUS_MODE] ❌ لا يمكن الانتقال: لم يتم العثور على بيانات البلاغ كاملة في الذاكرة المؤقتة');
      _showErrorSnackBar('خطأ: لم يتم العثور على بيانات البلاغ كاملة');
      return;
    }

    debugPrint(
        '🎯 [FOCUS_MODE] ✅ تم استرجاع بيانات البلاغ كاملة للبلاغ ${fullReport.id}');
    debugPrint(
        '🎯 [FOCUS_MODE] موقع البلاغ: ${fullReport.latitude}, ${fullReport.longitude}');
    debugPrint(
        '🎯 [FOCUS_MODE] اسم البلاغ: ${fullReport.state?.report?.name ?? "غير معروف"}');
    debugPrint(
        '🎯 [FOCUS_MODE] نوع الطوارئ: ${fullReport.state?.emergencyType ?? "غير معروف"}');
    debugPrint('🎯 [FOCUS_MODE] جاري إنشاء MultiBlocProvider...');

    try {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) {
            debugPrint(
                '🎯 [FOCUS_MODE] جاري بناء FocusModeScreen ببيانات البلاغ الكاملة...');
            return MultiBlocProvider(
              providers: [
                BlocProvider.value(value: context.read<ChatCubit>()),
                BlocProvider.value(value: context.read<UsersLocationCubit>()),
                BlocProvider.value(value: context.read<AuthCubit>()),
              ],
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: FocusModeScreen(
                  activeAssignment: activeAssignment,
                  fullReport: fullReport,
                  currentPosition: _currentPosition,
                ),
              ),
            );
          },
        ),
      );
      debugPrint(
          '🎯 [FOCUS_MODE] ✅ تم بدء الانتقال إلى وضع التركيز ببيانات البلاغ الكاملة');
    } catch (e, stackTrace) {
      debugPrint('🚨 [FOCUS_MODE] خطأ في الانتقال: $e');
      debugPrint('🚨 [FOCUS_MODE] تتبع الخطأ: $stackTrace');
    }
  }

  // ============================================================================
  // إدارة إشعارات المهام (ASSIGNMENT NOTIFICATION MANAGEMENT)
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
      _showErrorSnackBar("فشل في قبول المهمة: ${e.toString()}");
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
      _showErrorSnackBar("فشل في رفض المهمة: ${e.toString()}");
      setState(() => _isProcessingAssignmentAction = false);
    }
  }

  // ============================================================================
  // رسائل التنبيه والتنظيف (SNACKBARS & CLEANUP)
  // ============================================================================

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline, color: Colors.white),
        const SizedBox(width: 8),
        Expanded(child: Text(message, textAlign: TextAlign.right))
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
        Expanded(child: Text(message, textAlign: TextAlign.right))
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
  // بناء الواجهة (BUILD METHOD & UI STRUCTURE)
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: _buildAppBar(),
        body: Stack(
          children: [
            BlocListener<AssignmentsCubit, AssignmentsState>(
              listener: _handleAssignmentsStateChange,
              child: _buildBody(),
            ),
            if (_isAssignmentNotificationVisible &&
                _pendingAssignmentRequest != null)
              _buildAssignmentNotificationOverlay(),
          ],
        ),
        bottomNavigationBar: _buildBottomNavigation(),
        floatingActionButton:
            widget.userType == UserType.citizen ? _buildCitizenFAB() : null,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    String title;
    switch (widget.userType) {
      case UserType.citizen:
        title = 'رجال الإنقاذ';
        break;
      case UserType.responder:
        title = 'الاستجابة للطوارئ';
        break;
      case UserType.coordinator:
        title = 'عمليات الطوارئ';
        break;
    }
    return AppBar(
      title: Text(title),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      actions: [
        if (_networkError != null)
          IconButton(
            icon: Icon(Icons.signal_wifi_off, color: Colors.orange[700]),
            onPressed: () {
              _handleManualRefresh;
            },
            tooltip: 'مشاكل في الاتصال - اضغط لإعادة المحاولة',
          ),
        if (_activeAssignment != null && _canPerformResponderActions())
          Container(
            margin: const EdgeInsets.only(left: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: Colors.blue.shade600,
                borderRadius: BorderRadius.circular(12)),
            child: const Text('مهمة فعالة',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
          ),
        IconButton(
          icon: const Icon(Icons.person_outline),
          onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const Directionality(
                      textDirection: TextDirection.rtl,
                      child: ProfileScreen()))),
          tooltip: 'الملف الشخصي',
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
        onShowFilters: () {},
        onShowReportDetails: _showReportDetails,
        onShowUserDetails: _showUserDetails,
        onGetDirections: _getAndDisplayRoute,
        onClearRoute: _clearRoute,
        onUpdateAssignmentStatus: _updateAssignmentStatus,
        onMapReady: _onMapReady,
      ),
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
      context.read<AuthCubit>().isAuthenticated
          ? const ChatsListScreenAR()
          : _buildAuthRequiredMessage(),
    ];
  }

  Widget _buildBottomNavigation() {
    return Material(
      elevation: 8,
      child: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(icon: Icon(Icons.map_outlined), text: 'الخريطة'),
          Tab(icon: Icon(Icons.report_outlined), text: 'البلاغات'),
          Tab(icon: Icon(Icons.chat_outlined), text: 'الدردشة'),
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
      Text('جاري تهيئة خريطة الطوارئ الذكية...',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700])),
      const SizedBox(height: 8),
      Text('جاري إعداد لوحة تحكم الطوارئ الخاصة بك',
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
              Text('المصادقة مطلوبة',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text('يرجى تسجيل الدخول للوصول إلى ميزات الدردشة.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey[600])),
            ])));
  }

  // ============================================================================
  // استرجاع بيانات البلاغ المعززة (ENHANCED REPORT DATA RETRIEVAL)
  // ============================================================================

  ReportEntity? _getEnhancedReportData(ParticipationRequest request) {
    if (request.report?.id == null) return null;

    try {
      final reportId = request.report.id;
      final cachedReport =
          _cachedReports.where((r) => r.id == reportId).firstOrNull;

      if (cachedReport != null) {
        debugPrint(
            '🚨 [ASSIGNMENT_POPUP] تم العثور على بيانات بلاغ محسّنة للبلاغ $reportId');
        return cachedReport;
      } else {
        debugPrint(
            '🚨 [ASSIGNMENT_POPUP] لم يتم العثور على البلاغ $reportId في الذاكرة المؤقتة، باستخدام البيانات الأساسية');
        return null;
      }
    } catch (e) {
      debugPrint(
          '🚨 [ASSIGNMENT_POPUP] خطأ في استرجاع بيانات البلاغ المحسّنة: $e');
      return null;
    }
  }

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

  Color _getSeverityColor(double? severity) {
    if (severity == null) return Colors.grey.shade600;
    if (severity >= 0.8) return Colors.red.shade700;
    if (severity >= 0.6) return Colors.orange.shade600;
    if (severity >= 0.4) return Colors.yellow.shade600;
    return Colors.green.shade600;
  }

  String _getSeverityLabel(double? severity) {
    if (severity == null) return 'غير محدد';
    if (severity >= 0.8) return 'حرج جداً';
    if (severity >= 0.6) return 'عاجل';
    if (severity >= 0.4) return 'متوسط';
    return 'عادي';
  }

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

  String? _getUserDisplayName(int userId) {
    try {
      final user = _otherUsers.where((u) => u.id == userId).firstOrNull;
      return user?.name;
    } catch (e) {
      debugPrint('🚨 [ASSIGNMENT_POPUP] خطأ في الحصول على اسم المستخدم: $e');
      return null;
    }
  }

  // ============================================================================
  // تراكب إشعار مهمة الطوارئ (EMERGENCY ASSIGNMENT NOTIFICATION OVERLAY)
  // ============================================================================

  Widget _buildAssignmentNotificationOverlay() {
    final request = _pendingAssignmentRequest!;
    final basicReport = request.report;
    final enhancedReport = _getEnhancedReportData(request);

    final emergencyType = enhancedReport?.state?.emergencyType;
    final severity = enhancedReport?.state?.severity;
    final reportName =
        enhancedReport?.state?.report?.name ?? 'بلاغ طوارئ #${basicReport.id}';
    final reportDescription = enhancedReport?.state?.report?.description ??
        enhancedReport?.state?.report?.text;
    final emergencySubType = enhancedReport?.state?.emergencySubType;
    final location = enhancedReport?.fullAddress ?? 'موقع غير محدد';
    final distance = enhancedReport?.distance ?? 'غير محدد';
    final eta = _calculateETA(enhancedReport?.distance);

    debugPrint(
        '🚨 [ASSIGNMENT_NOTIFICATION] جاري بناء إشعار مضغوط للطلب ${request.id}');
    debugPrint('🚨 [ASSIGNMENT_NOTIFICATION] اسم البلاغ: $reportName');
    debugPrint(
        '🚨 [ASSIGNMENT_NOTIFICATION] نوع الطوارئ: $emergencyType, النوع الفرعي: $emergencySubType');
    debugPrint(
        '🚨 [ASSIGNMENT_NOTIFICATION] الخطورة: $severity, المسافة: $distance');

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 500),
      curve: Curves.elasticOut,
      top: _isAssignmentNotificationVisible ? 0 : -400,
      left: 0,
      right: 0,
      child: Container(
        margin: const EdgeInsets.all(16),
        constraints: const BoxConstraints(maxHeight: 500),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.red.shade700, Colors.red.shade600],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.4),
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
                              textDirection: TextDirection.rtl,
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
                                textDirection: TextDirection.rtl,
                              ),
                            Text(
                              'طلب رقم #${request.id}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14,
                              ),
                              textDirection: TextDirection.ltr,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _dismissAssignmentNotification,
                        icon: const Icon(Icons.close,
                            color: Colors.white, size: 28),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.3), width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.report_problem,
                                color: Colors.amber.shade300, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                reportName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                textDirection: TextDirection.rtl,
                              ),
                            ),
                          ],
                        ),
                        if (reportDescription != null &&
                            reportDescription.isNotEmpty) ...[
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
                              textDirection: TextDirection.rtl,
                            ),
                          ),
                        ],
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
                                textDirection: TextDirection.rtl,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '(${(severity * 100).toInt()}%)',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 12,
                                ),
                                textDirection: TextDirection.ltr,
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  if (location.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.3), width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.location_on,
                                  color: Colors.red.shade300, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'معلومات الموقع',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                textDirection: TextDirection.rtl,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            location,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                              height: 1.3,
                            ),
                            textDirection: TextDirection.rtl,
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
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
                                        Colors.white),
                                  ),
                                )
                              : const Icon(Icons.check_circle,
                                  color: Colors.white, size: 20),
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
                                borderRadius: BorderRadius.circular(14)),
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
                          icon: const Icon(Icons.cancel_outlined,
                              color: Colors.white, size: 20),
                          label: const Text(
                            'رفض المهمة',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side:
                                const BorderSide(color: Colors.white, width: 2),
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            backgroundColor: Colors.white.withOpacity(0.1),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.2), width: 1),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: Colors.white.withOpacity(0.8), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'قبول المهمة سينقلك تلقائياً إلى وضع التركيز مع التنقل GPS',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 12,
                            ),
                            textDirection: TextDirection.rtl,
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
      ),
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

  String _calculateETA(String? distanceString) {
    if (distanceString == null || distanceString == 'غير محدد') {
      return '';
    }

    try {
      final regex = RegExp(r'(\d+\.?\d*)');
      final match = regex.firstMatch(distanceString);

      if (match != null) {
        final distanceKm = double.parse(match.group(1)!);

        const emergencySpeedKmh = 40.0;

        final timeHours = distanceKm / emergencySpeedKmh;
        final timeMinutes = (timeHours * 60).round();

        debugPrint(
            '🚨 [ASSIGNMENT_NOTIFICATION] حساب الوقت المقدر: ${distanceKm}كم بسرعة ${emergencySpeedKmh}كم/س = ${timeMinutes}دقيقة');

        if (timeMinutes < 1) {
          return 'أقل من دقيقة';
        } else if (timeMinutes < 60) {
          return '$timeMinutes د';
        } else {
          final hours = timeMinutes ~/ 60;
          final minutes = timeMinutes % 60;
          return minutes > 0 ? '${hours}س ${minutes}د' : '${hours}س';
        }
      }
    } catch (e) {
      debugPrint('🚨 [ASSIGNMENT_NOTIFICATION] خطأ في حساب الوقت المقدر: $e');
    }

    return '';
  }
}
