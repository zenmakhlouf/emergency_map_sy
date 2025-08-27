import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';
import '../features/reports/cubit/reports_cubit.dart';
import '../features/reports/models/report.dart';
import 'report_emergency_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  LatLng _currentPosition = const LatLng(31.9539, 35.9106); // Default to Amman
  bool _isLoading = true;
  DateTime? _lastRefreshed;
  Timer? _poller;
  final Duration _pollInterval = const Duration(seconds: 5);
  List<ReportEntity> _cachedReports = <ReportEntity>[];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchReportsForPosition(_currentPosition);
      _startPolling();
    });
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
      _fetchReportsForPosition(_currentPosition);
      //_mapController.move(_currentPosition, 14);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location: ${e.toString()}')),
        );
      }
      setState(() {
        _isLoading = false;
      });
      _fetchReportsForPosition(_currentPosition);
    }
  }

  void _fetchReportsForPosition(LatLng position) {
    try {
      context.read<ReportsCubit>().fetchReports(query: {
        'map_list': 1,
        'get': 1,
        'location[lat]': position.latitude,
        'location[lon]': position.longitude,
      }).then((_) {
        setState(() {
          _lastRefreshed = DateTime.now();
        });
      });
    } catch (e) {
      // avoid crash if provider missing
    }
  }

  void _startPolling() {
    _poller?.cancel();
    _poller = Timer.periodic(_pollInterval, (_) {
      _fetchReportsForPosition(_currentPosition);
    });
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
          : BlocBuilder<ReportsCubit, ReportsState>(
              builder: (context, state) {
                if (state is ReportsFailure && _cachedReports.isEmpty) {
                  return Center(
                      child: Text('Failed to load reports: ${state.message}'));
                }
                if (state is ReportsSuccess) {
                  _cachedReports = state.reports;
                }
                final List<ReportEntity> reports = _cachedReports;

                return FlutterMap(
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
                                _getIconForEmergencyType(
                                    report.state?.emergencyType),
                                color: _getColorForEmergencyType(
                                    report.state?.emergencyType),
                                size: 40,
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                    Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: GestureDetector(
                          onTap: () =>
                              _fetchReportsForPosition(_currentPosition),
                          child: Chip(
                            backgroundColor: Colors.white,
                            label: Text(
                                'Last refresh: ${_formattedLastRefreshed()}  ·  Tap to refresh'),
                          ),
                        ),
                      ),
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
              Text(
                report.description,
                style: const TextStyle(fontSize: 16),
              ),
              const Spacer(),
              // CTA removed in new flow
            ],
          ),
        );
      },
    );
  }
}
