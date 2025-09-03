/// Service to handle navigation to map with specific reports
/// This allows communication between chat screens and dashboard map
class MapNavigationService {
  static final MapNavigationService _instance = MapNavigationService._internal();
  factory MapNavigationService() => _instance;
  MapNavigationService._internal();

  int? _pendingReportId;
  Function(int)? _mapCenterCallback;

  /// Set a report ID to be shown on the map when returning to dashboard
  void setPendingReportId(int reportId) {
    _pendingReportId = reportId;
    // If callback is already registered, call it immediately
    if (_mapCenterCallback != null) {
      _mapCenterCallback!(reportId);
      _pendingReportId = null;
    }
  }

  /// Register a callback from the dashboard map to center on report by ID
  void registerMapCenterCallback(Function(int) callback) {
    _mapCenterCallback = callback;
    // If there's a pending report ID, center on it now
    if (_pendingReportId != null) {
      callback(_pendingReportId!);
      _pendingReportId = null;
    }
  }

  /// Clear the callback when dashboard is disposed
  void clearMapCenterCallback() {
    _mapCenterCallback = null;
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