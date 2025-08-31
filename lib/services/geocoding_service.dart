// services/geocoding_service.dart
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;

class GeocodingService {
  static const String _baseUrl = 'https://nominatim.openstreetmap.org';
  static const Duration _timeout = Duration(seconds: 10);
  static const String _userAgent = 'EmergencyMapApp/1.0';

  // Cache for geocoding results to reduce API calls
  static final Map<String, GeocodingResult> _cache = {};

  /// Reverse geocode coordinates to address with Arabic language support
  static Future<GeocodingResult> reverseGeocode(
    LatLng coordinates, {
    String language = 'ar,en',
    bool useCache = true,
  }) async {
    final cacheKey =
        '${coordinates.latitude.toStringAsFixed(6)},${coordinates.longitude.toStringAsFixed(6)}';

    // Check cache first
    if (useCache && _cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    try {
      final url = '$_baseUrl/reverse'
          '?format=json'
          '&lat=${coordinates.latitude}'
          '&lon=${coordinates.longitude}'
          '&zoom=18'
          '&addressdetails=1'
          '&accept-language=$language'
          '&extratags=1';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': _userAgent,
          'Accept': 'application/json',
        },
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final result = GeocodingResult.fromNominatimResponse(data, coordinates);

        // Cache the result
        if (useCache) {
          _cache[cacheKey] = result;
        }

        return result;
      } else {
        throw GeocodingException(
            'HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      if (e is TimeoutException) {
        throw GeocodingException('Request timed out');
      } else if (e is GeocodingException) {
        rethrow;
      } else {
        throw GeocodingException('Network error: ${e.toString()}');
      }
    }
  }

  /// Forward geocode address to coordinates
  static Future<List<GeocodingResult>> forwardGeocode(
    String address, {
    String language = 'ar,en',
    int limit = 5,
  }) async {
    try {
      final encodedAddress = Uri.encodeComponent(address);
      final url = '$_baseUrl/search'
          '?q=$encodedAddress'
          '&format=json'
          '&addressdetails=1'
          '&limit=$limit'
          '&accept-language=$language';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': _userAgent,
          'Accept': 'application/json',
        },
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List<dynamic>;
        return data
            .map((item) => GeocodingResult.fromNominatimSearch(item))
            .toList();
      } else {
        throw GeocodingException(
            'HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      if (e is TimeoutException) {
        throw GeocodingException('Request timed out');
      } else if (e is GeocodingException) {
        rethrow;
      } else {
        throw GeocodingException('Network error: ${e.toString()}');
      }
    }
  }

  /// Clear the geocoding cache
  static void clearCache() {
    _cache.clear();
  }

  /// Get cache size
  static int get cacheSize => _cache.length;
}

class GeocodingResult {
  final LatLng coordinates;
  final String displayName;
  final String? houseNumber;
  final String? road;
  final String? neighbourhood;
  final String? suburb;
  final String? city;
  final String? state;
  final String? country;
  final String? postcode;
  final Map<String, dynamic>? rawData;

  const GeocodingResult({
    required this.coordinates,
    required this.displayName,
    this.houseNumber,
    this.road,
    this.neighbourhood,
    this.suburb,
    this.city,
    this.state,
    this.country,
    this.postcode,
    this.rawData,
  });

  factory GeocodingResult.fromNominatimResponse(
    Map<String, dynamic> data,
    LatLng coordinates,
  ) {
    final address = data['address'] as Map<String, dynamic>?;

    return GeocodingResult(
      coordinates: coordinates,
      displayName: data['display_name'] as String? ?? '',
      houseNumber: address?['house_number'] as String?,
      road: address?['road'] as String?,
      neighbourhood: address?['neighbourhood'] as String?,
      suburb: address?['suburb'] as String?,
      city: address?['city'] as String? ??
          address?['town'] as String? ??
          address?['village'] as String?,
      state: address?['state'] as String?,
      country: address?['country'] as String?,
      postcode: address?['postcode'] as String?,
      rawData: data,
    );
  }

  factory GeocodingResult.fromNominatimSearch(Map<String, dynamic> data) {
    final lat = double.tryParse(data['lat'] as String? ?? '') ?? 0.0;
    final lon = double.tryParse(data['lon'] as String? ?? '') ?? 0.0;

    return GeocodingResult.fromNominatimResponse(
      data,
      LatLng(lat, lon),
    );
  }

  /// Get a short, formatted address
  String get shortAddress {
    List<String> parts = [];

    if (road != null) parts.add(road!);
    if (neighbourhood != null && neighbourhood != road)
      parts.add(neighbourhood!);
    if (city != null) parts.add(city!);

    if (parts.isEmpty && displayName.isNotEmpty) {
      // Fallback to first part of display name
      final firstPart = displayName.split(',').first.trim();
      if (firstPart.isNotEmpty) parts.add(firstPart);
    }

    return parts.isEmpty
        ? '${coordinates.latitude.toStringAsFixed(4)}, ${coordinates.longitude.toStringAsFixed(4)}'
        : parts.join(', ');
  }

  /// Get a medium-length formatted address
  String get mediumAddress {
    List<String> parts = [];

    if (houseNumber != null && road != null) {
      parts.add('$houseNumber $road');
    } else if (road != null) {
      parts.add(road!);
    }

    if (neighbourhood != null && neighbourhood != road)
      parts.add(neighbourhood!);
    if (city != null) parts.add(city!);
    if (state != null && state != city) parts.add(state!);

    return parts.isEmpty ? shortAddress : parts.join(', ');
  }

  /// Get the full formatted address
  String get fullAddress {
    if (displayName.isNotEmpty) {
      return displayName;
    }
    return mediumAddress;
  }

  /// Check if this is a high-quality geocoding result
  bool get isHighQuality {
    return road != null || city != null || displayName.isNotEmpty;
  }

  @override
  String toString() => fullAddress;
}

class GeocodingException implements Exception {
  final String message;

  const GeocodingException(this.message);

  @override
  String toString() => 'GeocodingException: $message';
}

/// Helper mixin for classes that need geocoding functionality
mixin GeocodingMixin {
  String? _lastGeocodedAddress;
  LatLng? _lastGeocodedPosition;

  /// Update address from coordinates with caching and error handling
  Future<String> updateAddressFromCoordinates(
    LatLng position, {
    String language = 'ar',
    bool forceRefresh = false,
  }) async {
    // Check if we need to geocode (position changed significantly or forced refresh)
    if (!forceRefresh &&
        _lastGeocodedPosition != null &&
        _lastGeocodedAddress != null) {
      final distance = _calculateDistance(_lastGeocodedPosition!, position);
      if (distance < 0.1) {
        // Less than 100 meters
        return _lastGeocodedAddress!;
      }
    }

    try {
      final result = await GeocodingService.reverseGeocode(
        position,
        language: language,
      );

      if (result.isHighQuality) {
        _lastGeocodedAddress = result.fullAddress;
        _lastGeocodedPosition = position;
        return result.fullAddress;
      } else {
        // Fallback to coordinates if geocoding quality is poor
        return _formatCoordinates(position);
      }
    } catch (e) {
      print('Geocoding failed: $e');
      return _formatCoordinates(position);
    }
  }

  String _formatCoordinates(LatLng position) {
    return '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
  }

  double _calculateDistance(LatLng pos1, LatLng pos2) {
    const double earthRadius = 6371; // Earth's radius in kilometers

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

extension NumMath on num {
  double get sqrt => math.sqrt(toDouble());
  double get sin => math.sin(toDouble());
  double get cos => math.cos(toDouble());
  double get asin => math.asin(toDouble());
}
