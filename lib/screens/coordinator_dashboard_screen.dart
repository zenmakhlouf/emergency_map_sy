import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';
import '../features/reports/cubit/reports_cubit.dart';
import '../features/reports/models/report.dart';
import '../features/auth/models/user_type.dart';
import 'emergency_chat_screen.dart';

class CoordinatorDashboardScreen extends StatefulWidget {
  const CoordinatorDashboardScreen({super.key});

  @override
  State<CoordinatorDashboardScreen> createState() =>
      _CoordinatorDashboardScreenState();
}

class _CoordinatorDashboardScreenState extends State<CoordinatorDashboardScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  late TabController _tabController;
  DateTime? _lastRefreshed;
  final Duration _pollInterval = const Duration(seconds: 5);
  Timer? _poller;
  final LatLng _currentPosition = const LatLng(31.9539, 35.9106);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchReports();
      _startPolling();
    });
  }

  @override
  void dispose() {
    _poller?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchReports() async {
    try {
      await context.read<ReportsCubit>().fetchReports(query: {
        'map_list': 1,
        'get': 1,
        'location[lat]': _currentPosition.latitude,
        'location[lon]': _currentPosition.longitude,
      });
      setState(() {
        _lastRefreshed = DateTime.now();
      });
    } catch (_) {}
  }

  void _startPolling() {
    _poller?.cancel();
    _poller = Timer.periodic(_pollInterval, (_) => _fetchReports());
  }

  String _formattedLastRefreshed() {
    if (_lastRefreshed == null) return 'Never';
    final dt = _lastRefreshed!;
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SafetyConnect'),
            Text(
              'Emergency Operations Center',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              // TODO: Implement coordinator profile
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildMapTab(),
          _buildAnalyticsTab(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Colors.grey, width: 0.5)),
        ),
        child: TabBar(
          controller: _tabController,
          labelColor: Colors.red,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.red,
          tabs: const [
            Tab(
              icon: Icon(Icons.dashboard),
              text: 'Overview',
            ),
            Tab(
              icon: Icon(Icons.map),
              text: 'Map',
            ),
            Tab(
              icon: Icon(Icons.analytics),
              text: 'Analytics',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    return BlocBuilder<ReportsCubit, ReportsState>(
      builder: (context, state) {
        if (state is ReportsFailure) {
          return const Center(child: Text('Failed to load reports'));
        }

        if (state is ReportsSuccess) {
          // fallthrough to render
        }

        final List<ReportEntity> reports =
            state is ReportsSuccess ? state.reports : <ReportEntity>[];
        final activeCount = reports.length;
        final criticalCount =
            reports.where((r) => (r.state?.severity ?? 0) >= 8).length;
        final highPriorityCount =
            reports.where((r) => (r.state?.severity ?? 0) >= 6).length;

        return RefreshIndicator(
          onRefresh: _fetchReports,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status Cards
                Row(
                  children: [
                    Expanded(
                      child: _buildStatusCard(
                        'Active Incidents',
                        activeCount.toString(),
                        Icons.emergency,
                        Colors.red,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatusCard(
                        'Critical',
                        criticalCount.toString(),
                        Icons.warning,
                        Colors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatusCard(
                        'High Priority',
                        highPriorityCount.toString(),
                        Icons.priority_high,
                        Colors.amber,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatusCard(
                        'Responders',
                        '12',
                        Icons.security,
                        Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _fetchReports,
                        icon: const Icon(Icons.refresh),
                        label: Text('Refresh • ${_formattedLastRefreshed()}'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const SizedBox(height: 16),

                // Recent Incidents
                const Text(
                  'Recent Incidents',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                if (reports.isEmpty)
                  const Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 64,
                          color: Colors.green,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'All Clear',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'No active incidents at the moment',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: reports.length,
                    itemBuilder: (context, index) {
                      final report = reports[index];
                      return _buildIncidentCard(report);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMapTab() {
    return BlocBuilder<ReportsCubit, ReportsState>(
      builder: (context, state) {
        if (state is ReportsLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final List<ReportEntity> reports =
            state is ReportsSuccess ? state.reports : <ReportEntity>[];
        final center = reports.isNotEmpty
            ? LatLng(
                reports.map((r) => r.latitude).reduce((a, b) => a + b) /
                    reports.length,
                reports.map((r) => r.longitude).reduce((a, b) => a + b) /
                    reports.length,
              )
            : const LatLng(31.9539, 35.9106);

        return Column(
          children: [
            Expanded(
              child: Card(
                margin: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.map, color: Colors.red),
                          const SizedBox(width: 8),
                          const Text(
                            'Live Incident Map',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${reports.length} active',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: center,
                          initialZoom: reports.isNotEmpty ? 12 : 14,
                          maxZoom: 18,
                          minZoom: 3,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName:
                                'com.example.emergency_map_sy',
                          ),
                          MarkerLayer(
                            markers: reports.map((report) {
                              return Marker(
                                width: 50.0,
                                height: 50.0,
                                point:
                                    LatLng(report.latitude, report.longitude),
                                child: GestureDetector(
                                  onTap: () {
                                    _showIncidentDetails(context, report);
                                  },
                                  child: Icon(
                                    _getIconForEmergencyType(
                                        report.state?.emergencyType),
                                    color: _getColorForEmergencyType(
                                        report.state?.emergencyType),
                                    size: 40,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          Align(
                            alignment: Alignment.topCenter,
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: GestureDetector(
                                onTap: _fetchReports,
                                child: Chip(
                                  backgroundColor: Colors.white,
                                  label: Text(
                                      'Last refresh: ${_formattedLastRefreshed()}  ·  Tap to refresh'),
                                ),
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
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('Dispatching additional responders')),
                        );
                      },
                      icon: const Icon(Icons.send),
                      label: const Text('Dispatch'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('Broadcasting alert to all responders')),
                        );
                      },
                      icon: const Icon(Icons.broadcast_on_personal),
                      label: const Text('Broadcast'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAnalyticsTab() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.analytics,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'Analytics Dashboard',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Coming soon...',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
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
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncidentCard(ReportEntity report) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              _getColorForEmergencyType(report.state?.emergencyType),
          child: Icon(
            _getIconForEmergencyType(report.state?.emergencyType),
            color: Colors.white,
          ),
        ),
        title: Text(
          report.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(report.description),
            const SizedBox(height: 4),
            Row(
              children: [
                Chip(
                  label: Text(
                    (report.state?.emergencyType ?? 'unknown').toString(),
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                  ),
                  backgroundColor:
                      _getColorForEmergencyType(report.state?.emergencyType),
                ),
                const SizedBox(width: 8),
                Text(
                  '${report.formattedDate} at ${report.formattedTime}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'monitor':
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EmergencyChatScreen(
                      incidentTitle: report.title,
                      userType: UserType.coordinator,
                    ),
                  ),
                );
                break;
              case 'details':
                _showIncidentDetails(context, report);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'monitor',
              child: Row(
                children: [
                  Icon(Icons.visibility),
                  SizedBox(width: 8),
                  Text('Monitor'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'details',
              child: Row(
                children: [
                  Icon(Icons.info),
                  SizedBox(width: 8),
                  Text('Details'),
                ],
              ),
            ),
          ],
        ),
        onTap: () => _showIncidentDetails(context, report),
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

  void _showIncidentDetails(BuildContext context, ReportEntity report) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16.0),
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      report.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Chip(
                    backgroundColor:
                        _getColorForEmergencyType(report.state?.emergencyType),
                    label: Text(
                      (report.state?.emergencyType ?? 'unknown').toString(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('${report.formattedDate} at ${report.formattedTime}'),
              const SizedBox(height: 16),
              Expanded(
                child: Text(
                  report.description,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EmergencyChatScreen(
                              incidentTitle: report.title,
                              userType: UserType.coordinator,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Monitor Incident'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('Dispatching additional responders')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Dispatch'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
