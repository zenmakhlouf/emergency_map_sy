import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/emergency_report.dart';
import '../features/auth/models/user_type.dart';
import '../services/emergency_service.dart';
import 'emergency_chat_screen.dart';

class EmergencyReportFormScreen extends StatefulWidget {
  const EmergencyReportFormScreen({super.key});

  @override
  State<EmergencyReportFormScreen> createState() => _EmergencyReportFormScreenState();
}

class _EmergencyReportFormScreenState extends State<EmergencyReportFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  EmergencyType _selectedType = EmergencyType.nonEmergency;
  int _volunteersNeeded = 1;
  late LatLng _selectedPosition;
  final MapController _mapController = MapController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Default to Amman coordinates
    _selectedPosition = const LatLng(31.9539, 35.9106);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Emergency'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<EmergencyType>(
                decoration: const InputDecoration(
                  labelText: 'Emergency Type',
                  border: OutlineInputBorder(),
                ),
                value: _selectedType,
                onChanged: (EmergencyType? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedType = newValue;
                    });
                  }
                },
                items: EmergencyType.values.map((EmergencyType type) {
                  return DropdownMenuItem<EmergencyType>(
                    value: type,
                    child: Text(type.toString().split('.').last),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Volunteers needed:'),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Slider(
                      value: _volunteersNeeded.toDouble(),
                      min: 1,
                      max: 10,
                      divisions: 9,
                      label: _volunteersNeeded.toString(),
                      onChanged: (double value) {
                        setState(() {
                          _volunteersNeeded = value.toInt();
                        });
                      },
                    ),
                  ),
                  Text('$_volunteersNeeded'),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Mark the location on the map:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                height: 300,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _selectedPosition,
                    initialZoom: 16,
                    onTap: (tapPosition, point) {
                      setState(() {
                        _selectedPosition = point;
                      });
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c'],
                      userAgentPackageName: 'com.example.emergency_map_sy',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          width: 40.0,
                          height: 40.0,
                          point: _selectedPosition,
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Submit Report'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitReport() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSubmitting = true;
      });

      try {
        EmergencyReport report = EmergencyReport(
          id: '', // Firestore will generate
          title: _titleController.text,
          description: _descriptionController.text,
          type: _selectedType,
          latitude: _selectedPosition.latitude,
          longitude: _selectedPosition.longitude,
          timestamp: DateTime.now(),
          volunteersNeeded: _volunteersNeeded,
          volunteers: [],
          isActive: true,
        );

        final emergencyService = EmergencyService();
        await emergencyService.addReport(report);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Emergency reported successfully')),
          );
          
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => EmergencyChatScreen(
                incidentTitle: 'Emergency Report',
                userType: UserType.citizen,
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.toString()}')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
        }
      }
    }
  }
} 