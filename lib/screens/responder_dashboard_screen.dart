import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../models/emergency_report.dart';
import '../services/emergency_service.dart';
import '../features/auth/models/user_type.dart';
import 'emergency_chat_screen.dart';

class ResponderDashboardScreen extends StatefulWidget {
  const ResponderDashboardScreen({super.key});

  @override
  State<ResponderDashboardScreen> createState() =>
      _ResponderDashboardScreenState();
}

class _ResponderDashboardScreenState extends State<ResponderDashboardScreen>
    with SingleTickerProviderStateMixin {
  final EmergencyService _emergencyService = EmergencyService();
  final MapController _mapController = MapController();
  LatLng _currentPosition = const LatLng(31.9539, 35.9106); // Default to Amman
  bool _isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled')),
        );
      }
      setState(() {
        _isLoading = false;
      });
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied')),
          );
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permissions are permanently denied'),
          ),
        );
      }
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location: ${e.toString()}')),
        );
      }
      setState(() {
        _isLoading = false;
      });
    }
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
              'Emergency Response',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              // TODO: Implement responder profile
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMapTab(),
          _buildActiveIncidentsTab(),
          _buildChatTab(),
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
              icon: Icon(Icons.map),
              text: 'Map',
            ),
            Tab(
              icon: Icon(Icons.emergency),
              text: 'Incidents',
            ),
            Tab(
              icon: Icon(Icons.chat),
              text: 'Chat',
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const EmergencyChatScreen(
                incidentTitle: 'Emergency Response',
                userType: UserType.responder,
              ),
            ),
          );
        },
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        child: const Icon(Icons.chat),
      ),
    );
  }

  Widget _buildMapTab() {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : StreamBuilder<List<EmergencyReport>>(
            stream: _emergencyService.getActiveReports(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final reports = snapshot.data ?? [];

              return Column(
                children: [
                  // Map Card
                  Card(
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
                                'Active Incidents Map',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.my_location),
                                onPressed: () {
                                  _mapController.move(_currentPosition, 15);
                                },
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: 300,
                          child: FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter: _currentPosition,
                              initialZoom: 14,
                              maxZoom: 18,
                              minZoom: 3,
                              onMapReady: () {
                                _mapController.move(_currentPosition, 14);
                              },
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName:
                                    'com.example.emergency_map_sy',
                              ),
                              MarkerLayer(
                                markers: [
                                  // Responder's current location marker
                                  Marker(
                                    width: 40.0,
                                    height: 40.0,
                                    point: _currentPosition,
                                    child: const Icon(
                                      Icons.location_on,
                                      color: Colors.blue,
                                      size: 40,
                                    ),
                                  ),
                                  // Emergency report markers
                                  ...reports.map((report) {
                                    return Marker(
                                      width: 50.0,
                                      height: 50.0,
                                      point: LatLng(
                                          report.latitude, report.longitude),
                                      child: GestureDetector(
                                        onTap: () {
                                          _showIncidentDetails(context, report);
                                        },
                                        child: Icon(
                                          _getIconForEmergencyType(report.type),
                                          color: _getColorForEmergencyType(
                                              report.type),
                                          size: 40,
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Quick Actions
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              // TODO: Implement "I'm on my way" functionality
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Status updated: On my way')),
                              );
                            },
                            icon: const Icon(Icons.directions_car),
                            label: const Text('On My Way'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              // TODO: Implement "Arrived" functionality
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Status updated: Arrived at scene')),
                              );
                            },
                            icon: const Icon(Icons.check_circle),
                            label: const Text('Arrived'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
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

  Widget _buildActiveIncidentsTab() {
    return StreamBuilder<List<EmergencyReport>>(
      stream: _emergencyService.getActiveReports(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final reports = snapshot.data ?? [];

        if (reports.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.emergency,
                  size: 64,
                  color: Colors.grey,
                ),
                SizedBox(height: 16),
                Text(
                  'No active incidents',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'All clear for now',
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

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: reports.length,
          itemBuilder: (context, index) {
            final report = reports[index];
            return _buildIncidentCard(report);
          },
        );
      },
    );
  }

  Widget _buildChatTab() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'No active conversations',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Chat will appear here when you respond to an incident',
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
              case 'respond':
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EmergencyChatScreen(
                      incidentTitle: report.title,
                      userType: UserType.responder,
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
              value: 'respond',
              child: Row(
                children: [
                  Icon(Icons.chat),
                  SizedBox(width: 8),
                  Text('Respond'),
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
          height: MediaQuery.of(context).size.height * 0.5,
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
                              userType: UserType.responder,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Respond to Incident'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Status updated: On my way')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('On My Way'),
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
