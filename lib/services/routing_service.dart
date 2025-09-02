// services/routing_service.dart
import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

class RoutingService {
  // Multiple OSRM servers for redundancy
  static const List<String> _osrmServers = [
    'http://router.project-osrm.org',
    'https://routing.openstreetmap.de/routed-car',
  ];

  static const Duration _timeout = Duration(seconds: 15);
  static const String _userAgent = 'EmergencyMapApp/1.0';

  /// Get route between two points using OSRM
  static Future<RouteResult> getRoute(
    LatLng origin,
    LatLng destination, {
    String profile = 'driving', // driving, walking, cycling
    bool alternatives = false,
    bool steps = true,
  }) async {
    final originStr = "${origin.longitude},${origin.latitude}";
    final destinationStr = "${destination.longitude},${destination.latitude}";

    Exception? lastError;

    // Try each OSRM server
    for (final server in _osrmServers) {
      try {
        final url = '$server/route/v1/$profile/$originStr;$destinationStr'
            '?overview=full'
            '&geometries=geojson'
            '&steps=${steps ? 'true' : 'false'}'
            '&alternatives=${alternatives ? 'true' : 'false'}';

        final response = await http.get(
          Uri.parse(url),
          headers: {
            'User-Agent': _userAgent,
            'Accept': 'application/json',
          },
        ).timeout(_timeout);

        if (response.statusCode == 200) {
          final data = json.decode(response.body) as Map<String, dynamic>;
          return RouteResult.fromOSRMResponse(data, origin, destination);
        } else {
          lastError =
              RoutingException('HTTP ${response.statusCode} from $server');
        }
      } catch (e) {
        lastError = e is Exception ? e : RoutingException(e.toString());
        continue; // Try next server
      }
    }

    throw lastError ?? const RoutingException('All routing servers failed');
  }

  /// Open directions in browser using OpenStreetMap
  static Future<void> openDirectionsInBrowser(
    LatLng origin,
    LatLng destination, {
    String transportMode = 'car', // car, foot, bicycle
  }) async {
    final osmUrl = 'https://www.openstreetmap.org/directions'
        '?from=${origin.latitude},${origin.longitude}'
        '&to=${destination.latitude},${destination.longitude}'
        '&route=$transportMode';

    try {
      final uri = Uri.parse(osmUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw const RoutingException('Cannot open browser for directions');
      }
    } catch (e) {
      throw RoutingException('Failed to open directions: $e');
    }
  }

  /// Get multiple routing options for emergency response
  static Future<List<RouteResult>> getEmergencyRoutes(
    LatLng origin,
    LatLng destination,
  ) async {
    final List<RouteResult> routes = [];

    // Try to get driving route with alternatives
    try {
      final drivingRoute = await getRoute(
        origin,
        destination,
        profile: 'driving',
        alternatives: true,
      );
      routes.add(drivingRoute);
    } catch (e) {
      print('Failed to get driving route: $e');
    }

    return routes;
  }

  /// Calculate estimated arrival time based on current traffic
  static Future<DateTime> getEstimatedArrival(
    LatLng origin,
    LatLng destination,
  ) async {
    try {
      final route = await getRoute(origin, destination);
      final estimatedDurationMinutes = route.durationMinutes;
      return DateTime.now()
          .add(Duration(minutes: estimatedDurationMinutes.round()));
    } catch (e) {
      // Fallback calculation based on straight-line distance
      final distance = _calculateStraightLineDistance(origin, destination);
      final estimatedMinutes =
          (distance / 0.5).round(); // Assume 30 km/h average
      return DateTime.now().add(Duration(minutes: estimatedMinutes));
    }
  }

  static double _calculateStraightLineDistance(LatLng pos1, LatLng pos2) {
    const double earthRadius = 6371;

    final lat1Rad = pos1.latitude * (3.14159265359 / 180);
    final lat2Rad = pos2.latitude * (3.14159265359 / 180);
    final deltaLatRad = (pos2.latitude - pos1.latitude) * (3.14159265359 / 180);
    final deltaLonRad =
        (pos2.longitude - pos1.longitude) * (3.14159265359 / 180);

    final a = (deltaLatRad / 2).sin * (deltaLatRad / 2).sin +
        lat1Rad.cos *
            lat2Rad.cos *
            (deltaLonRad / 2).sin *
            (deltaLonRad / 2).sin;
    final c = 2 * a.sqrt.asin;

    return earthRadius * c;
  }
}

class RouteResult {
  final LatLng origin;
  final LatLng destination;
  final double distanceKm;
  final double durationMinutes;
  final List<LatLng> geometry;
  final List<RouteStep> steps;
  final String? errorMessage;

  const RouteResult({
    required this.origin,
    required this.destination,
    required this.distanceKm,
    required this.durationMinutes,
    required this.geometry,
    required this.steps,
    this.errorMessage,
  });

  factory RouteResult.fromOSRMResponse(
    Map<String, dynamic> data,
    LatLng origin,
    LatLng destination,
  ) {
    final routes = data['routes'] as List<dynamic>?;

    if (routes == null || routes.isEmpty) {
      return RouteResult(
        origin: origin,
        destination: destination,
        distanceKm: 0,
        durationMinutes: 0,
        geometry: [],
        steps: [],
        errorMessage: 'No route found',
      );
    }

    final route = routes[0] as Map<String, dynamic>;
    final distance = (route['distance'] as num? ?? 0) / 1000; // Convert to km
    final duration =
        (route['duration'] as num? ?? 0) / 60; // Convert to minutes

    // Parse geometry
    final geometryData = route['geometry'] as Map<String, dynamic>?;
    final coordinates = geometryData?['coordinates'] as List<dynamic>? ?? [];
    final geometry = coordinates.map((coord) {
      final coordList = coord as List<dynamic>;
      return LatLng(coordList[1] as double, coordList[0] as double);
    }).toList();

    // Parse steps
    final legs = route['legs'] as List<dynamic>? ?? [];
    final steps = <RouteStep>[];

    for (final leg in legs) {
      final legSteps = leg['steps'] as List<dynamic>? ?? [];
      for (final step in legSteps) {
        steps.add(RouteStep.fromOSRMStep(step as Map<String, dynamic>));
      }
    }

    return RouteResult(
      origin: origin,
      destination: destination,
      distanceKm: distance,
      durationMinutes: duration,
      geometry: geometry,
      steps: steps,
    );
  }

  String get formattedDuration {
    if (durationMinutes < 1) {
      return '< 1 min';
    } else if (durationMinutes < 60) {
      return '${durationMinutes.round()} min';
    } else {
      final hours = durationMinutes ~/ 60;
      final minutes = durationMinutes % 60;
      return '${hours}h ${minutes.round()}m';
    }
  }

  String get formattedDistance {
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).round()} m';
    } else {
      return '${distanceKm.toStringAsFixed(1)} km';
    }
  }

  bool get isValid => geometry.isNotEmpty && distanceKm > 0;
}

class RouteStep {
  final String instruction;
  final double distanceKm;
  final double durationMinutes;
  final LatLng location;

  const RouteStep({
    required this.instruction,
    required this.distanceKm,
    required this.durationMinutes,
    required this.location,
  });

  factory RouteStep.fromOSRMStep(Map<String, dynamic> step) {
    final maneuver = step['maneuver'] as Map<String, dynamic>? ?? {};
    final location = maneuver['location'] as List<dynamic>? ?? [0, 0];
    final instruction = step['name'] as String? ??
        step['maneuver']?['type'] as String? ??
        'Continue';

    return RouteStep(
      instruction: instruction,
      distanceKm: (step['distance'] as num? ?? 0) / 1000,
      durationMinutes: (step['duration'] as num? ?? 0) / 60,
      location: LatLng(location[1] as double, location[0] as double),
    );
  }
}

class RoutingException implements Exception {
  final String message;

  const RoutingException(this.message);

  @override
  String toString() => 'RoutingException: $message';
}

extension NumMath on num {
  double get sqrt => math.sqrt(toDouble());
  double get sin => math.sin(toDouble());
  double get cos => math.cos(toDouble());
  double get asin => math.asin(toDouble());
}