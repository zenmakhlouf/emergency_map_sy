/// Custom exception for location-related errors
class LocationException implements Exception {
  final String message;

  const LocationException(this.message);

  @override
  String toString() => 'LocationException: $message';
}
