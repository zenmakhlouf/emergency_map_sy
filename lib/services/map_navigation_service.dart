/// Service to handle navigation to map with specific reports
/// This allows communication between chat screens and dashboard map
class MapNavigationService {
  static final MapNavigationService _instance = MapNavigationService._internal();
  factory MapNavigationService() => _instance;
  MapNavigationService._internal();

  int? _pendingReportId;
  Function(int, {double zoom})? _mapCenterCallback;
  bool _isMapReady = false;

  /// Set a report ID to be shown on the map when returning to dashboard
  void setPendingReportId(int reportId) {
    _pendingReportId = reportId;
    // If callback is already registered and map is ready, call it immediately
    if (_mapCenterCallback != null && _isMapReady) {
      _mapCenterCallback!(reportId, zoom: 17.0); // Use higher zoom for reports
      _pendingReportId = null;
    }
  }

  /// Navigate to report on map with higher zoom (for immediate navigation)
  void navigateToReportOnMap(int reportId) {
    if (_mapCenterCallback != null && _isMapReady) {
      // Map is ready - navigate immediately with higher zoom
      _mapCenterCallback!(reportId, zoom: 17.0);
    } else {
      // Queue for when map becomes ready
      setPendingReportId(reportId);
    }
  }

  /// Register a callback from the dashboard map to center on report by ID
  void registerMapCenterCallback(Function(int, {double zoom}) callback) {
    _mapCenterCallback = callback;
    // If there's a pending report ID and map is ready, center on it now
    if (_pendingReportId != null && _isMapReady) {
      callback(_pendingReportId!, zoom: 17.0);
      _pendingReportId = null;
    }
  }

  /// Mark the map as ready for navigation
  void setMapReady() {
    _isMapReady = true;
    // Process any pending report navigation
    if (_pendingReportId != null && _mapCenterCallback != null) {
      _mapCenterCallback!(_pendingReportId!, zoom: 17.0);
      _pendingReportId = null;
    }
  }

  /// Clear the callback when dashboard is disposed
  void clearMapCenterCallback() {
    _mapCenterCallback = null;
    _isMapReady = false;
  }

  /// Check if there's a pending report ID
  bool get hasPendingReportId => _pendingReportId != null;

  /// Get the pending report ID and clear it
  int? consumePendingReportId() {
    final reportId = _pendingReportId;
    _pendingReportId = null;
    return reportId;
  }
}