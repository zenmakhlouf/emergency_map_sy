import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../models/emergency_report.dart';
import '../services/emergency_service.dart';
import 'report_emergency_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final EmergencyService _emergencyService = EmergencyService();
  final MapController _mapController = MapController();
  LatLng _currentPosition = const LatLng(31.9539, 35.9106); // Default to Amman
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled, show a message to user
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
        // Permissions are denied, show a message
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
      // Permissions are permanently denied, handle appropriately
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

    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    try {
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });
      _mapController.move(_currentPosition, 14);
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
        title: const Text('Emergency Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () {
              _mapController.move(_currentPosition, 15);
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<EmergencyReport>>(
              stream: _emergencyService.getActiveReports(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final reports = snapshot.data ?? [];

                return FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentPosition,
                    initialZoom: 14,
                    maxZoom: 18,
                    minZoom: 3,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName:
                          'com.example.emergency_map_sy', // Replace with your actual package name
                      // Alternative: you can also use additionalOptions for more control
                      // additionalOptions: {
                      //   'User-Agent': 'YourAppName/1.0.0 (contact@yourdomain.com)',
                      // },
                    ),
                    MarkerLayer(
                      markers: [
                        // User's current location marker
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
                            point: LatLng(report.latitude, report.longitude),
                            child: GestureDetector(
                              onTap: () {
                                _showReportDetails(context, report);
                              },
                              child: Icon(
                                _getIconForEmergencyType(report.type),
                                color: _getColorForEmergencyType(report.type),
                                size: 40,
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ],
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReportEmergencyScreen(
                initialPosition: _currentPosition,
              ),
            ),
          );
        },
        tooltip: 'Report Emergency',
        child: const Icon(Icons.add),
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

  void _showReportDetails(BuildContext context, EmergencyReport report) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16.0),
          height: MediaQuery.of(context).size.height * 0.4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    report.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
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
              Text(
                report.description,
                style: const TextStyle(fontSize: 16),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  // For MVP, just show a confirmation without actually storing the volunteer
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('You volunteered to help!'),
                    ),
                  );
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                child: const Text('Volunteer to Help'),
              ),
            ],
          ),
        );
      },
    );
  }
}
