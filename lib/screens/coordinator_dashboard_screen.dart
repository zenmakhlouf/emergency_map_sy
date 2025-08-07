import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/emergency_report.dart';
import '../services/emergency_service.dart';
import '../models/user_type.dart';
import 'emergency_chat_screen.dart';

class CoordinatorDashboardScreen extends StatefulWidget {
  const CoordinatorDashboardScreen({super.key});

  @override
  State<CoordinatorDashboardScreen> createState() => _CoordinatorDashboardScreenState();
}

class _CoordinatorDashboardScreenState extends State<CoordinatorDashboardScreen>
    with SingleTickerProviderStateMixin {
  final EmergencyService _emergencyService = EmergencyService();
  final MapController _mapController = MapController();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
    return StreamBuilder<List<EmergencyReport>>(
      stream: _emergencyService.getActiveReports(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final reports = snapshot.data ?? [];
        final activeCount = reports.length;
        final criticalCount = reports.where((r) => r.type == EmergencyType.lifeThreatening).length;
        final highPriorityCount = reports.where((r) => r.type == EmergencyType.burglary).length;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
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
              const SizedBox(height: 24),

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
        );
      },
    );
  }

  Widget _buildMapTab() {
    return StreamBuilder<List<EmergencyReport>>(
      stream: _emergencyService.getActiveReports(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final reports = snapshot.data ?? [];
        final center = reports.isNotEmpty 
            ? LatLng(
                reports.map((r) => r.latitude).reduce((a, b) => a + b) / reports.length,
                reports.map((r) => r.longitude).reduce((a, b) => a + b) / reports.length,
              )
            : const LatLng(31.9539, 35.9106); // Default to Amman

        return Column(
          children: [
            // Map
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
                                point: LatLng(report.latitude, report.longitude),
                                child: GestureDetector(
                                  onTap: () {
                                    _showIncidentDetails(context, report);
                                  },
                                  child: Icon(
                                    _getIconForEmergencyType(report.type),
                                    color: _getColorForEmergencyType(report.type),
                                    size: 40,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Quick Actions
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // TODO: Implement dispatch functionality
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Dispatching additional responders')),
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
                        // TODO: Implement broadcast functionality
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Broadcasting alert to all responders')),
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

  Widget _buildStatusCard(String title, String value, IconData icon, Color color) {
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

  Widget _buildIncidentCard(EmergencyReport report) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getColorForEmergencyType(report.type),
          child: Icon(
            _getIconForEmergencyType(report.type),
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
                    report.type.toString().split('.').last,
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                  ),
                  backgroundColor: _getColorForEmergencyType(report.type),
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

  IconData _getIconForEmergencyType(EmergencyType type) {
    switch (type) {
      case EmergencyType.burglary:
        return Icons.home_work;
      case EmergencyType.lifeThreatening:
        return Icons.emergency;
      case EmergencyType.suspicious:
        return Icons.visibility;
      case EmergencyType.unusualSounds:
        return Icons.volume_up;
      case EmergencyType.nonEmergency:
        return Icons.info;
    }
  }

  Color _getColorForEmergencyType(EmergencyType type) {
    switch (type) {
      case EmergencyType.burglary:
        return Colors.amber;
      case EmergencyType.lifeThreatening:
        return Colors.red;
      case EmergencyType.suspicious:
        return Colors.orange;
      case EmergencyType.unusualSounds:
        return Colors.purple;
      case EmergencyType.nonEmergency:
        return Colors.green;
    }
  }

  void _showIncidentDetails(BuildContext context, EmergencyReport report) {
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
                    backgroundColor: _getColorForEmergencyType(report.type),
                    label: Text(
                      report.type.toString().split('.').last,
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
                          const SnackBar(content: Text('Dispatching additional responders')),
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