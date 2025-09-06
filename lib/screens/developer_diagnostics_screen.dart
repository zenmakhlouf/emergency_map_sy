import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../features/auth/cubit/auth_cubit.dart';
import '../features/users_location/repo/locationservice.dart';
import '../apis/network.dart';
import '../utils/urls.dart';
import '../utils/location_config.dart';

class DeveloperDiagnosticsScreen extends StatefulWidget {
  const DeveloperDiagnosticsScreen({Key? key}) : super(key: key);

  @override
  State<DeveloperDiagnosticsScreen> createState() => _DeveloperDiagnosticsScreenState();
}

class _DeveloperDiagnosticsScreenState extends State<DeveloperDiagnosticsScreen> {
  final ScrollController _scrollController = ScrollController();
  Map<String, dynamic> diagnosticsData = {};
  bool isLoading = true;
  List<String> errorLogs = [];

  @override
  void initState() {
    super.initState();
    _runDiagnostics();
  }

  Future<void> _runDiagnostics() async {
    setState(() {
      isLoading = true;
      diagnosticsData.clear();
      errorLogs.clear();
    });

    try {
      // Authentication Status - CRITICAL
      diagnosticsData['authentication'] = await _getAuthenticationStatus();
      
      // Location Services - CRITICAL
      diagnosticsData['location'] = await _getLocationStatus();
      
      // Network & API Tests - CRITICAL
      diagnosticsData['network'] = await _getNetworkStatus();
      
      // Location Configuration - CRITICAL
      diagnosticsData['config'] = _getLocationConfig();
      
      // Location Service Tests - CRITICAL
      diagnosticsData['locationService'] = await _testLocationService();
      
      // Exception Tracking
      diagnosticsData['exceptions'] = await _getExceptionLogs();
      
    } catch (e) {
      errorLogs.add('Diagnostics Error: $e');
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<Map<String, dynamic>> _testLocationService() async {
    try {
      final locationService = LocationService(baseUrl: Urls.baseUrl);
      Map<String, dynamic> results = {};
      
      // Test location update with dummy data
      try {
        await locationService.updateUserLocation(
          lat: 33.5, 
          lon: 36.3, 
          address: 'Test Location Update'
        );
        results['locationUpdate'] = {
          'success': true,
          'message': 'Location update successful',
        };
      } catch (e) {
        results['locationUpdate'] = {
          'success': false,
          'error': e.toString(),
        };
        errorLogs.add('Location Update Test Failed: $e');
      }
      
      // Test users location fetch
      try {
        final usersResponse = await locationService.getUsersLocations();
        results['usersLocationFetch'] = {
          'success': usersResponse.success,
          'usersCount': usersResponse.users.length,
          'message': usersResponse.message,
        };
      } catch (e) {
        results['usersLocationFetch'] = {
          'success': false,
          'error': e.toString(),
        };
        errorLogs.add('Users Location Fetch Test Failed: $e');
      }
      
      return results;
    } catch (e) {
      errorLogs.add('Location Service Test Error: $e');
      return {'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _getAuthenticationStatus() async {
    try {
      final authCubit = context.read<AuthCubit>();
      final prefs = await SharedPreferences.getInstance();
      
      return {
        'isAuthenticated': authCubit.isAuthenticated,
        'userId': authCubit.userId,
        'userType': authCubit.userType?.name,
        'tokenLength': authCubit.token?.length ?? 0,
        'tokenPresent': authCubit.token != null && authCubit.token!.isNotEmpty,
        'storedToken': prefs.getString('auth_token')?.length ?? 0,
        'storedUserId': prefs.getInt('user_id'),
        'storedUserType': prefs.getString('user_type'),
        'networkBearerSet': Network.dio.options.headers['Authorization'] != null,
        'networkBearerValue': Network.dio.options.headers['Authorization']?.toString().substring(0, 20) ?? 'None',
      };
    } catch (e) {
      errorLogs.add('Authentication Status Error: $e');
      return {'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _getLocationStatus() async {
    try {
      bool serviceEnabled = false;
      LocationPermission permission = LocationPermission.denied;
      Position? position;
      
      try {
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
        permission = await Geolocator.checkPermission();
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        );
      } catch (e) {
        errorLogs.add('Location Service Error: $e');
      }

      return {
        'serviceEnabled': serviceEnabled,
        'permission': permission.name,
        'currentPosition': position != null ? {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy': position.accuracy,
          'timestamp': position.timestamp.toIso8601String(),
        } : null,
        'platform': Platform.operatingSystem,
      };
    } catch (e) {
      errorLogs.add('Location Status Error: $e');
      return {'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _getExceptionLogs() async {
    try {
      // Return current error logs and any stored exceptions
      final prefs = await SharedPreferences.getInstance();
      final storedErrors = prefs.getStringList('error_logs') ?? [];
      
      return {
        'currentErrors': errorLogs,
        'storedErrors': storedErrors,
        'totalErrors': errorLogs.length + storedErrors.length,
        'lastError': storedErrors.isNotEmpty ? storedErrors.last : 'None',
      };
    } catch (e) {
      errorLogs.add('Exception Logs Error: $e');
      return {'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _getNetworkStatus() async {
    try {
      // Test network connectivity by making actual API calls
      Map<String, dynamic> networkStatus = {
        'baseUrl': Urls.baseUrl,
        'networkHeaders': Network.dio.options.headers,
      };

      // Test auth endpoint
      try {
        final authResponse = await Network.getData(url: Urls.profile);
        networkStatus['authEndpointTest'] = {
          'success': true,
          'statusCode': authResponse.statusCode,
          'responseTime': DateTime.now().millisecondsSinceEpoch,
        };
      } catch (e) {
        networkStatus['authEndpointTest'] = {
          'success': false,
          'error': e.toString(),
        };
      }

      // Test users endpoint
      try {
        final usersResponse = await Network.getData(url: '${Urls.baseUrl}/users');
        networkStatus['usersEndpointTest'] = {
          'success': true,
          'statusCode': usersResponse.statusCode,
          'responseTime': DateTime.now().millisecondsSinceEpoch,
        };
      } catch (e) {
        networkStatus['usersEndpointTest'] = {
          'success': false,
          'error': e.toString(),
        };
      }

      return networkStatus;
    } catch (e) {
      errorLogs.add('Network Status Error: $e');
      return {'error': e.toString()};
    }
  }

  Map<String, dynamic> _getLocationConfig() {
    return {
      'disableResponderLocationPolling': LocationConfig.disableResponderLocationPolling,
      'disableUsersLocationPolling': LocationConfig.disableUsersLocationPolling,
      'disableOwnLocationPolling': LocationConfig.disableOwnLocationPolling,
    };
  }


  String _formatDiagnosticsData() {
    StringBuffer buffer = StringBuffer();
    buffer.writeln('=== EMERGENCY MAP DIAGNOSTICS REPORT ===');
    buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln('');
    
    diagnosticsData.forEach((category, data) {
      buffer.writeln('[$category]');
      _formatMapToString(data, buffer, 1);
      buffer.writeln('');
    });
    
    if (errorLogs.isNotEmpty) {
      buffer.writeln('[ERROR LOGS]');
      for (final error in errorLogs) {
        buffer.writeln('  - $error');
      }
      buffer.writeln('');
    }
    
    return buffer.toString();
  }

  void _formatMapToString(dynamic data, StringBuffer buffer, int indent) {
    String indentStr = '  ' * indent;
    
    if (data is Map<String, dynamic>) {
      data.forEach((key, value) {
        if (value is Map<String, dynamic> || value is List) {
          buffer.writeln('$indentStr$key:');
          _formatMapToString(value, buffer, indent + 1);
        } else {
          buffer.writeln('$indentStr$key: $value');
        }
      });
    } else if (data is List) {
      for (int i = 0; i < data.length; i++) {
        buffer.writeln('$indentStr[$i]:');
        _formatMapToString(data[i], buffer, indent + 1);
      }
    } else {
      buffer.writeln('$indentStr$data');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Developer Diagnostics'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _runDiagnostics,
          ),
          IconButton(
            icon: Icon(Icons.share),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _formatDiagnosticsData()));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Diagnostics copied to clipboard!')),
              );
            },
          ),
        ],
      ),
      body: isLoading 
        ? Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            controller: _scrollController,
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildErrorSection(),
                _buildDiagnosticsSection('🔐 Authentication', diagnosticsData['authentication']),
                _buildDiagnosticsSection('📍 Location Services', diagnosticsData['location']),
                _buildDiagnosticsSection('🌐 Network & API Tests', diagnosticsData['network']),
                _buildDiagnosticsSection('⚙️ Location Configuration', diagnosticsData['config']),
                _buildDiagnosticsSection('🧪 Location Service Tests', diagnosticsData['locationService']),
                _buildDiagnosticsSection('💥 Exception Tracking', diagnosticsData['exceptions']),
                SizedBox(height: 20),
                _buildExportSection(),
              ],
            ),
          ),
    );
  }

  Widget _buildErrorSection() {
    if (errorLogs.isEmpty) return SizedBox.shrink();
    
    return Card(
      color: Colors.red.shade50,
      margin: EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error, color: Colors.red),
                SizedBox(width: 8),
                Text('ERRORS DETECTED', style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                )),
              ],
            ),
            SizedBox(height: 8),
            ...errorLogs.map((error) => Padding(
              padding: EdgeInsets.symmetric(vertical: 2),
              child: Text('• $error', style: TextStyle(color: Colors.red.shade700)),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildDiagnosticsSection(String title, dynamic data) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: _buildDataWidget(data),
          ),
        ],
      ),
    );
  }

  Widget _buildDataWidget(dynamic data) {
    if (data == null) {
      return Text('No data available', style: TextStyle(color: Colors.grey));
    }
    
    if (data is Map<String, dynamic>) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: data.entries.map((entry) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Text('${entry.key}:', style: TextStyle(fontWeight: FontWeight.w500)),
                ),
                Expanded(
                  flex: 3,
                  child: _buildValueWidget(entry.value),
                ),
              ],
            ),
          );
        }).toList(),
      );
    } else {
      return Text(data.toString());
    }
  }

  Widget _buildValueWidget(dynamic value) {
    if (value is bool) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: value ? Colors.green.shade100 : Colors.red.shade100,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          value.toString().toUpperCase(),
          style: TextStyle(
            color: value ? Colors.green.shade700 : Colors.red.shade700,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    } else if (value is Map<String, dynamic>) {
      return _buildDataWidget(value);
    } else {
      return SelectableText(value.toString());
    }
  }

  Widget _buildExportSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Export Diagnostics', style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            )),
            SizedBox(height: 8),
            Text('Share this diagnostics report with developers for troubleshooting.'),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _formatDiagnosticsData()));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Full report copied to clipboard!')),
                      );
                    },
                    icon: Icon(Icons.copy),
                    label: Text('Copy to Clipboard'),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _runDiagnostics,
                    icon: Icon(Icons.refresh),
                    label: Text('Refresh Data'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}