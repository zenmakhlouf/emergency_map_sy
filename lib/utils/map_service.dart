import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// A service class for handling map-related functionalities like routing and geocoding.
class MapServices {
  /// Fetches a route between two points using the OSRM (Open Source Routing Machine) API.
  /// Returns a list of `LatLng` points representing the route polyline.
  static Future<List<LatLng>> getRoute(LatLng start, LatLng end) async {
    final url =
        'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final coordinates = data['routes'][0]['geometry']['coordinates'];
        return coordinates
            .map<LatLng>((coord) => LatLng(coord[1], coord[0]))
            .toList();
      } else {
        debugPrint('OSRM Error: ${response.body}');
        return [];
      }
    } catch (e) {
      debugPrint('Error fetching route: $e');
      return [];
    }
  }

  /// Converts coordinates into a human-readable address using the OpenStreetMap Nominatim API.
  /// Caches results to avoid redundant API calls for the same location.
  static final Map<String, String> _geocodeCache = {};

  static Future<String> getAddress(LatLng position,
      {String lang = 'ar'}) async {
    final cacheKey =
        '${position.latitude.toStringAsFixed(4)}_${position.longitude.toStringAsFixed(4)}';
    if (_geocodeCache.containsKey(cacheKey)) {
      return _geocodeCache[cacheKey]!;
    }

    final url =
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}&accept-language=$lang&zoom=18';

    try {
      final response = await http
          .get(Uri.parse(url), headers: {'User-Agent': 'EmergencyApp/1.0'});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final displayName =
            data['display_name'] as String? ?? 'Unknown Location';
        _geocodeCache[cacheKey] = displayName;
        return displayName;
      } else {
        return '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      }
    } catch (e) {
      debugPrint('Error getting address: $e');
      return '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
    }
  }
}
