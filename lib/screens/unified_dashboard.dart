import 'dart:async';
import 'package:emergency_map_sy/features/profile/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../features/reports/cubit/reports_cubit.dart';
import '../features/reports/models/report.dart';
import '../features/auth/cubit/auth_cubit.dart';
import '../features/auth/models/user_type.dart';
import '../features/chat/screens/ai_emergency_chat_screen.dart';
import '../features/chat/screens/chats_list_screen.dart';

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

  // Location and data state
  LatLng _currentPosition = const LatLng(33.5138, 36.2765); // Damascus default
  List<ReportEntity> _cachedReports = <ReportEntity>[];
  DateTime? _lastSuccessfulRefresh;

  // UI state management
  bool _isInitializing = true;
  bool _isLocationLoading = false;
  bool _isRefreshing = false;
  String? _locationError;
  String? _networkError;

  // Configuration constants
  static const Duration _pollInterval = Duration(seconds: 20);
  static const Duration _networkTimeout = Duration(seconds: 10);
  static const double _defaultZoom = 14.0;
  static const double _coordinatorZoom = 10.0;

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
    // Handle app lifecycle for better resource management
    switch (state) {
      case AppLifecycleState.resumed:
        _startPolling();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _stopPolling();
        break;
      default:
        break;
    }
  }

  // ============================================================================
  // INITIALIZATION METHODS
  // ============================================================================

  void _initializeTabController() {
    _tabController = TabController(
      length: _getTabConfiguration().length,
      vsync: this,
    );
  }

  /// Initialize the app by setting up auth and getting initial data
  Future<void> _initializeApp() async {
    try {
      // Initialize AuthCubit first to set network bearer token
      await _initializeAuth();

      // Get user location
      await _initializeLocation();

      // Load initial reports
      await _loadInitialReports();

      // Start polling for updates
      _startPolling();
    } catch (e) {
      debugPrint("Initialization error: $e");
      _handleInitializationError(e);
    } finally {
      if (mounted) {
        setState(() => _isInitializing = false);
      }
    }
  }

  /// Initialize authentication to set network bearer token
  Future<void> _initializeAuth() async {
    final authCubit = context.read<AuthCubit>();
    await context.read<AuthCubit>().waitForInitialization();
  }

  /// Get user's current location with proper error handling
  Future<void> _initializeLocation() async {
    if (!mounted) return;

    setState(() {
      _isLocationLoading = true;
      _locationError = null;
    });

    try {
      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw LocationException('Location services are disabled');
      }

      // Check and request permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw LocationException('Location permission denied');
      }

      // Get current position with timeout
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      if (mounted) {
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
          _locationError = null;
        });
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

  /// Load initial reports for the current position
  Future<void> _loadInitialReports() async {
    await _fetchReports();
  }

  // ============================================================================
  // DATA FETCHING METHODS
  // ============================================================================

  /// Fetch reports for current position with error handling
  Future<void> _fetchReports() async {
    if (!mounted) return;

    try {
      await context.read<ReportsCubit>().fetchReports(
        query: {
          'map_list': 1,
          'get': 1,
          'location[lat]': _currentPosition.latitude,
          'location[lon]': _currentPosition.longitude,
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

  /// Manual refresh triggered by user
  Future<void> _handleManualRefresh() async {
    if (!mounted || _isRefreshing) return;

    setState(() => _isRefreshing = true);

    try {
      await _fetchReports();
      _showSuccessSnackBar("Reports updated successfully");
    } catch (e) {
      _showErrorSnackBar("Failed to refresh reports");
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
    _stopPolling(); // Ensure no duplicate timers
    _reportPoller = Timer.periodic(_pollInterval, (_) {
      if (mounted) _fetchReports();
    });
  }

  void _stopPolling() {
    _reportPoller?.cancel();
    _reportPoller = null;
  }

  // ============================================================================
  // UI CONFIGURATION BY USER TYPE
  // ============================================================================

  List<Tab> _getTabConfiguration() {
    switch (widget.userType) {
      case UserType.citizen:
        return const [
          Tab(icon: Icon(Icons.map_outlined), text: 'Map'),
          Tab(icon: Icon(Icons.report_outlined), text: 'Reports'),
          Tab(icon: Icon(Icons.chat_outlined), text: 'Chat'),
        ];
      case UserType.responder:
      case UserType.coordinator:
        return const [
          Tab(icon: Icon(Icons.dashboard_outlined), text: 'Overview'),
          Tab(icon: Icon(Icons.map_outlined), text: 'Map'),
          Tab(icon: Icon(Icons.chat_outlined), text: 'Chat'),
        ];
      default:
        return const [Tab(icon: Icon(Icons.error), text: 'Error')];
    }
  }

  List<Widget> _getTabViews() {
    switch (widget.userType) {
      case UserType.citizen:
        return [
          _buildCitizenMapTab(),
          _buildReportsListTab(),
          _buildChatTab(),
        ];
      case UserType.responder:
        return [
          _buildReportsListTab(),
          _buildResponderMapTab(),
          _buildChatTab(),
        ];
      case UserType.coordinator:
        return [
          _buildCoordinatorOverviewTab(),
          _buildCoordinatorMapTab(),
          _buildChatTab(),
        ];
      default:
        return [_buildErrorTab()];
    }
  }

  Widget? _getFloatingActionButton() {
    if (widget.userType == UserType.citizen) {
      return FloatingActionButton(
        onPressed: () {
          _navigateToEmergencyChat();
        },
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        child: const Text('🚨', style: TextStyle(fontSize: 24)),
      );
    }
    return null;
  }

  // ============================================================================
  // TAB BUILDERS
  // ============================================================================

  Widget _buildCitizenMapTab() {
    return RefreshIndicator(
      onRefresh: _handleManualRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMapSection(),
            //_buildActionButtonsSection(),
            _buildNearbyIncidentsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildResponderMapTab() {
    return Stack(
      children: [
        _buildFullScreenMap(),
        _buildMapOverlayControls(),
      ],
    );
  }

  Widget _buildCoordinatorOverviewTab() {
    return RefreshIndicator(
      onRefresh: _handleManualRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOverviewHeader(),
            const SizedBox(height: 16),
            _buildStatisticsCards(),
            const SizedBox(height: 24),
            _buildActiveIncidentsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildCoordinatorMapTab() {
    return Stack(
      children: [
        _buildFullScreenMap(zoom: _coordinatorZoom),
        _buildMapOverlayControls(),
      ],
    );
  }

  Widget _buildReportsListTab() {
    return RefreshIndicator(
      onRefresh: _handleManualRefresh,
      child: Column(
        children: [
          _buildListHeader(),
          Expanded(child: _buildIncidentsList()),
        ],
      ),
    );
  }

  Widget _buildChatTab() {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthSuccess) {
          Future.delayed(const Duration(milliseconds: 101), () {
            if (mounted) {
              setState(() {});
            }
          });
        } else {
          Future.delayed(const Duration(milliseconds: 101), () {
            if (mounted) {
              setState(() {});
            }
          });
        }
      },
      child: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, authState) {
          if (context.read<AuthCubit>().isAuthenticated) {
            return const ChatsListScreen();
          }

          if (authState is AuthSuccess) {
            return const ChatsListScreen();
          }
          Future.delayed(const Duration(milliseconds: 101), () {
            if (mounted) {
              setState(() {});
            }
          });
          print("we have acgtivated this print statement auth: ${authState} ");
          return _buildAuthRequiredMessage();
        },
      ),
    );
  }

  Widget _buildErrorTab() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red),
          SizedBox(height: 16),
          Text(
            'Invalid User Role',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
        ],
      ),
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
            ],
          ),
        ),
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
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.emergency.map',
        ),
        MarkerLayer(markers: _buildMapMarkers()),
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

  Widget _buildActionButtonsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _isRefreshing ? null : _handleManualRefresh,
              icon: _isRefreshing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh, size: 18),
              label: Text(_getRefreshButtonText()),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _navigateToEmergencyChat,
              icon: const Icon(Icons.report_problem_outlined, size: 18),
              label: const Text('Report'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNearbyIncidentsSection() {
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
        _buildIncidentsList(),
      ],
    );
  }

  Widget _buildListHeader() {
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
                'Active Reports',
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

  Widget _buildOverviewHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Emergency Operations',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        _buildNetworkStatusIndicator(),
      ],
    );
  }

  Widget _buildStatisticsCards() {
    final stats = _calculateStatistics();

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Active Incidents',
                stats.activeCount.toString(),
                Icons.emergency,
                Colors.red.shade600,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'Critical',
                stats.criticalCount.toString(),
                Icons.warning_amber,
                Colors.orange.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Medical',
                stats.medicalCount.toString(),
                Icons.medical_services,
                Colors.purple.shade600,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'Fire',
                stats.fireCount.toString(),
                Icons.local_fire_department,
                Colors.deepOrange.shade600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActiveIncidentsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Incidents',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        _buildIncidentsList(),
      ],
    );
  }

  Widget _buildIncidentsList() {
    if (_cachedReports.isEmpty && !_isRefreshing) {
      return _buildEmptyState();
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _cachedReports.length,
      itemBuilder: (context, index) =>
          _buildIncidentCard(_cachedReports[index]),
    );
  }

  Widget _buildIncidentCard(ReportEntity report) {
    final emergencyType = report.state?.emergencyType;
    final severity = report.state?.severity ?? 5;

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
                      const SizedBox(height: 8),
                      _buildIncidentMetadata(report),
                    ],
                  ),
                ),
                _buildSeverityIndicator(severity),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIncidentIcon(String? emergencyType, int severity) {
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

  Widget _buildIncidentMetadata(ReportEntity report) {
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
      ],
    );
  }

  Widget _buildSeverityIndicator(int severity) {
    Color color;
    if (severity >= 8)
      color = Colors.red;
    else if (severity >= 6)
      color = Colors.orange;
    else
      color = Colors.yellow.shade700;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        severity.toString(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Colors.green.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'All Clear',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.green.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No active incidents in your area',
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

  List<Marker> _buildMapMarkers() {
    final markers = <Marker>[
      // User location marker
      Marker(
        point: _currentPosition,
        child: Container(
          decoration: BoxDecoration(
            color: _getUserLocationColor(),
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
          child: Icon(
            Icons.person_pin_circle,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),

      // Report markers
      ..._cachedReports.map((report) {
        return Marker(
          point: LatLng(report.latitude, report.longitude),
          child: GestureDetector(
            onTap: () => _showReportDetails(report),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _getColorForEmergencyType(report.state?.emergencyType),
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
                _getIconForEmergencyType(report.state?.emergencyType),
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        );
      }),
    ];

    return markers;
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  Color _getUserLocationColor() {
    switch (widget.userType) {
      case UserType.responder:
        return Colors.blue.shade600;
      case UserType.coordinator:
        return Colors.green.shade600;
      default:
        return Colors.teal.shade600;
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
      default:
        return Icons.emergency;
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
      default:
        return Colors.grey.shade600;
    }
  }

  String _getRefreshButtonText() {
    if (_isRefreshing) return 'Updating...';
    if (_lastSuccessfulRefresh != null) {
      return 'Refresh - ${_formatTime(_lastSuccessfulRefresh!)}';
    }
    return 'Refresh';
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

  EmergencyStatistics _calculateStatistics() {
    final activeCount = _cachedReports.length;
    final criticalCount =
        _cachedReports.where((r) => (r.state?.severity ?? 0) >= 8).length;
    final medicalCount = _cachedReports
        .where((r) => (r.state?.emergencyType ?? '').toLowerCase() == 'medical')
        .length;
    final fireCount = _cachedReports
        .where((r) => (r.state?.emergencyType ?? '').toLowerCase() == 'fire')
        .length;

    return EmergencyStatistics(
      activeCount: activeCount,
      criticalCount: criticalCount,
      medicalCount: medicalCount,
      fireCount: fireCount,
    );
  }

  // ============================================================================
  // EVENT HANDLERS
  // ============================================================================

  void _navigateToEmergencyChat() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AIEmergencyChatScreen()),
    );
  }

  Future<void> _centerMapOnCurrentLocation() async {
    if (_isLocationLoading) return;

    _mapController.move(_currentPosition, _defaultZoom);
    await _fetchReports();
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
                  // Header
                  Row(
                    children: [
                      _buildIncidentIcon(
                        report.state?.emergencyType,
                        report.state?.severity ?? 5,
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
                          ],
                        ),
                      ),
                      _buildSeverityIndicator(report.state?.severity ?? 5),
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

                  // Action buttons for responders/coordinators
                  if (widget.userType != UserType.citizen)
                    _buildReportActionButtons(report),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportActionButtons(ReportEntity report) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to detailed view or assignment screen
            },
            icon: const Icon(Icons.info_outline),
            label: const Text('Details'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to response/assignment screen
            },
            icon: const Icon(Icons.assignment_turned_in),
            label: const Text('Respond'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
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
            Text(message),
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
            Text(message),
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
    _tabController.dispose();
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
    return BlocListener<ReportsCubit, ReportsState>(
      listener: _handleReportsStateChange,
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
      default:
        return 'Emergency App';
    }
  }

  void _handleReportsStateChange(BuildContext context, ReportsState state) {
    if (!mounted) return;

    if (state is ReportsSuccess) {
      setState(() {
        _cachedReports = state.reports;
        _networkError = null;
        _lastSuccessfulRefresh = DateTime.now();
      });
    } else if (state is ReportsFailure) {
      setState(() {
        _networkError = state.message ?? "Failed to fetch reports";
      });
    }
  }
}

// ============================================================================
// HELPER CLASSES
// ============================================================================

/// Statistics model for coordinator overview
class EmergencyStatistics {
  final int activeCount;
  final int criticalCount;
  final int medicalCount;
  final int fireCount;

  const EmergencyStatistics({
    required this.activeCount,
    required this.criticalCount,
    required this.medicalCount,
    required this.fireCount,
  });
}

/// Custom exception for location-related errors
class LocationException implements Exception {
  final String message;

  const LocationException(this.message);

  @override
  String toString() => 'LocationException: $message';
}
