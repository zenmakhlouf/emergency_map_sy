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

class UnifiedDashboardScreen extends StatefulWidget {
  final UserType userType;

  const UnifiedDashboardScreen({
    super.key,
    required this.userType
  });

  @override
  State<UnifiedDashboardScreen> createState() => _UnifiedDashboardScreenState();
}

class _UnifiedDashboardScreenState extends State<UnifiedDashboardScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  LatLng _currentPosition =
      const LatLng(33.5138, 36.2765); // Default to Damascus
  bool _isLoading = true;
  late TabController _tabController;
  Timer? _poller;
  final Duration _pollInterval = const Duration(seconds: 20);
  List<ReportEntity> _cachedReports = <ReportEntity>[];
  DateTime? _lastRefreshed;

  @override
  void initState() {
    print("User type ${widget.userType.toString()}");
    super.initState();
    _tabController = TabController(
      length: _getTabsForUserType().length,
      vsync: this,
    );
    _initializeDashboard();
  }

  void _initializeDashboard() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _getCurrentLocation();
      _fetchReportsForPosition(_currentPosition);
      _startPolling();
    });
  }

  @override
  void dispose() {
    _poller?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _isLoading = false);
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isLoading = false);
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() => _isLoading = false);
        return;
      }
      Position position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint("Error getting location: $e");
    }
  }

  Future<void> _fetchReportsForPosition(LatLng position) async {
    if (mounted) {
      await context.read<ReportsCubit>().fetchReports(query: {
        'map_list': 1,
        'get': 1,
        'location[lat]': position.latitude,
        'location[lon]': position.longitude,
      });
      if (mounted) setState(() => _lastRefreshed = DateTime.now());
    }
  }

  void _startPolling() {
    _poller?.cancel();
    _poller = Timer.periodic(
        _pollInterval, (_) => _fetchReportsForPosition(_currentPosition));
  }

  // --- UI CONFIGURATION BASED ON USER TYPE ---

  List<Tab> _getTabsForUserType() {
    switch (widget.userType) {
      case UserType.citizen:
        return [
          const Tab(icon: Icon(Icons.map), text: 'Map'),
          const Tab(icon: Icon(Icons.report), text: 'Reports'),
          const Tab(icon: Icon(Icons.chat), text: 'Chat'),
        ];
      case UserType.responder:
      case UserType.coordinator:
        return [
          const Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
          const Tab(icon: Icon(Icons.map), text: 'Map'),
          const Tab(icon: Icon(Icons.chat), text: 'Chat'),
        ];
      default:
        return [const Tab(icon: Icon(Icons.error), text: 'Error')];
    }
  }

  List<Widget> _getTabViewsForUserType() {
    switch (widget.userType) {
      case UserType.citizen:
        return [
          _buildCitizenMapTab(),
          _buildIncidentsListTab(),
          _buildChatTab()
        ];
      case UserType.responder:
        return [
          _buildIncidentsListTab(),
          _buildResponderMapTab(),
          _buildChatTab()
        ];
      case UserType.coordinator:
        return [
          _buildCoordinatorOverviewTab(),
          _buildCoordinatorMapTab(),
          _buildChatTab()
        ];
      default:
        return [const Center(child: Text('Invalid User Role'))];
    }
  }

  Widget? _getFabForUserType() {
    if (widget.userType == UserType.citizen) {
      return FloatingActionButton(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AIEmergencyChatScreen())),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        tooltip: 'Report Emergency',
        child: const Text('🚨', style: TextStyle(fontSize: 24)),
      );
    }
    return null; // No FAB for other roles
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.userType == UserType.citizen
            ? 'SafetyConnect'
            : 'Emergency Operations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ProfileScreen())),
            tooltip: 'Profile',
          ),
        ],
      ),
      body: BlocListener<ReportsCubit, ReportsState>(
        listener: (context, state) {
          if (state is ReportsSuccess) {
            setState(() => _cachedReports = state.reports);
          }
        },
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: _getTabViewsForUserType(),
              ),
      ),
      bottomNavigationBar: TabBar(
        controller: _tabController,
        tabs: _getTabsForUserType(),
      ),
      floatingActionButton: _getFabForUserType(),
    );
  }

  // --- WIDGET BUILDERS PER ROLE ---

  // CITIZEN: Restored to original detailed layout
  Widget _buildCitizenMapTab() {
    return RefreshIndicator(
      onRefresh: () => _fetchReportsForPosition(_currentPosition),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            Card(
              margin: const EdgeInsets.all(16),
              child: SizedBox(
                height: 300,
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                      initialCenter: _currentPosition, initialZoom: 14),
                  children: [
                    TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
                    MarkerLayer(markers: _buildMapMarkers()),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _fetchReportsForPosition(_currentPosition),
                      icon: const Icon(Icons.refresh),
                      label: Text(
                          'Refresh • ${_lastRefreshed?.hour.toString().padLeft(2, '0')}:${_lastRefreshed?.minute.toString().padLeft(2, '0')}'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AIEmergencyChatScreen())),
                      icon: const Icon(Icons.add),
                      label: const Text('Report'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Nearby Incidents',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            _buildIncidentsList(),
          ],
        ),
      ),
    );
  }

  // RESPONDER
  Widget _buildResponderMapTab() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(initialCenter: _currentPosition, initialZoom: 14),
      children: [
        TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
        MarkerLayer(markers: _buildMapMarkers()),
      ],
    );
  }

  // COORDINATOR
  Widget _buildCoordinatorOverviewTab() {
    final activeCount = _cachedReports.length;
    final criticalCount =
        _cachedReports.where((r) => (r.state?.severity ?? 0) >= 8).length;

    return RefreshIndicator(
      onRefresh: () => _fetchReportsForPosition(_currentPosition),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                    child: _buildStatusCard('Active Incidents',
                        activeCount.toString(), Icons.emergency, Colors.red)),
                const SizedBox(width: 16),
                Expanded(
                    child: _buildStatusCard(
                        'Critical',
                        criticalCount.toString(),
                        Icons.warning,
                        Colors.orange)),
              ],
            ),
            const SizedBox(height: 24),
            _buildIncidentsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildCoordinatorMapTab() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(initialCenter: _currentPosition, initialZoom: 12),
      children: [
        TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
        MarkerLayer(markers: _buildMapMarkers()),
      ],
    );
  }

  // --- SHARED WIDGETS ---

  Widget _buildIncidentsListTab() {
    return RefreshIndicator(
      onRefresh: () => _fetchReportsForPosition(_currentPosition),
      child: _buildIncidentsList(),
    );
  }

  Widget _buildIncidentsList() {
    if (_cachedReports.isEmpty) {
      return const Center(
          child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('No active incidents nearby.'),
      ));
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _cachedReports.length,
      itemBuilder: (context, index) {
        final report = _cachedReports[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  _getColorForEmergencyType(report.state?.emergencyType),
              child: Icon(_getIconForEmergencyType(report.state?.emergencyType),
                  color: Colors.white),
            ),
            title: Text(report.title,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(report.description,
                maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () => _showReportDetails(context, report),
          ),
        );
      },
    );
  }

  Widget _buildChatTab() {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        final auth = context.read<AuthCubit>();
        if (auth.isAuthenticated) {
          return const ChatsListScreen();
        } else {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Please sign in to view and manage your conversations.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
          );
        }
      },
    );
  }

  // --- HELPER METHODS AND WIDGETS ---

  List<Marker> _buildMapMarkers() {
    return [
      Marker(
        point: _currentPosition,
        child: Icon(
          Icons.my_location,
          color: widget.userType == UserType.responder
              ? Colors.blue
              : Colors.green,
          size: 30,
        ),
      ),
      ..._cachedReports.map((report) {
        return Marker(
          point: LatLng(report.latitude, report.longitude),
          child: GestureDetector(
            onTap: () => _showReportDetails(context, report),
            child: Icon(
              _getIconForEmergencyType(report.state?.emergencyType),
              color: _getColorForEmergencyType(report.state?.emergencyType),
              size: 40,
            ),
          ),
        );
      }),
    ];
  }

  Widget _buildStatusCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(title,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  IconData _getIconForEmergencyType(String? apiType) {
    switch ((apiType ?? '').toLowerCase()) {
      case 'fire':
        return Icons.local_fire_department;
      case 'police':
        return Icons.local_police;
      case 'medical':
        return Icons.medical_services;
      default:
        return Icons.info;
    }
  }

  Color _getColorForEmergencyType(String? apiType) {
    switch ((apiType ?? '').toLowerCase()) {
      case 'fire':
        return Colors.red;
      case 'police':
        return Colors.blue;
      case 'medical':
        return Colors.purple;
      default:
        return Colors.green;
    }
  }

  void _showReportDetails(BuildContext context, ReportEntity report) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(report.title,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('${report.formattedDate} at ${report.formattedTime}',
                  style: const TextStyle(color: Colors.grey)),
              const Divider(height: 32),
              Text(report.description, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
