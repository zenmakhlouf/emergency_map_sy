import '../features/reports/models/report.dart';

/// Service to access the unified dashboard's report details sheet
/// This ensures all screens use the SAME report object and sheet instance
class ReportDetailsService {
  static UnifiedDashboardActions? _dashboardActions;
  
  /// Register the unified dashboard's actions
  static void registerDashboard(UnifiedDashboardActions actions) {
    _dashboardActions = actions;
  }
  
  /// Clear the dashboard reference when disposing
  static void clearDashboard() {
    _dashboardActions = null;
  }
  
  /// Show report details using the unified dashboard's method
  /// This uses the SAME ReportEntity object and _showReportDetails method
  static bool showReport(int reportId) {
    if (_dashboardActions == null) {
      return false; // Dashboard not available
    }
    
    final report = _dashboardActions!.getCachedReport(reportId);
    if (report != null) {
      _dashboardActions!.showReportDetails(report);
      return true;
    }
    
    return false; // Report not found
  }
  
  /// Check if dashboard is available
  static bool get isDashboardAvailable => _dashboardActions != null;
}

/// Interface for accessing unified dashboard actions
abstract class UnifiedDashboardActions {
  ReportEntity? getCachedReport(int reportId);
  void showReportDetails(ReportEntity report);
}