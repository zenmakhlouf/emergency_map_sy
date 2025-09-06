import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Central error logging utility for the application
class ErrorLogger {
  static const String _errorLogKey = 'error_logs';
  static const int _maxLogEntries = 100;

  /// Log an error with timestamp and context
  static Future<void> logError(String error, {String? context, StackTrace? stackTrace}) async {
    try {
      final timestamp = DateTime.now().toIso8601String();
      final logEntry = '[$timestamp] ${context != null ? '$context: ' : ''}$error';
      
      // Print to console for immediate debugging
      debugPrint('🔴 ERROR: $logEntry');
      if (stackTrace != null) {
        debugPrint('Stack trace: $stackTrace');
      }
      
      // Store in SharedPreferences for diagnostics
      final prefs = await SharedPreferences.getInstance();
      final existingLogs = prefs.getStringList(_errorLogKey) ?? [];
      
      // Add new log entry
      existingLogs.add(logEntry);
      
      // Keep only the most recent entries
      if (existingLogs.length > _maxLogEntries) {
        existingLogs.removeRange(0, existingLogs.length - _maxLogEntries);
      }
      
      await prefs.setStringList(_errorLogKey, existingLogs);
    } catch (e) {
      // Failsafe - if even logging fails, at least print to console
      debugPrint('🔴 CRITICAL: Failed to log error: $e. Original error: $error');
    }
  }
  
  /// Log location-specific errors
  static Future<void> logLocationError(String error, {Map<String, dynamic>? additionalData}) async {
    String contextualError = 'LOCATION: $error';
    if (additionalData != null) {
      contextualError += ' | Data: ${additionalData.toString()}';
    }
    await logError(contextualError, context: 'LocationService');
  }
  
  /// Log authentication errors
  static Future<void> logAuthError(String error, {Map<String, dynamic>? additionalData}) async {
    String contextualError = 'AUTH: $error';
    if (additionalData != null) {
      contextualError += ' | Data: ${additionalData.toString()}';
    }
    await logError(contextualError, context: 'Authentication');
  }
  
  /// Log network errors
  static Future<void> logNetworkError(String error, {String? url, int? statusCode}) async {
    String contextualError = 'NETWORK: $error';
    if (url != null) contextualError += ' | URL: $url';
    if (statusCode != null) contextualError += ' | Status: $statusCode';
    await logError(contextualError, context: 'Network');
  }
  
  /// Get all stored error logs
  static Future<List<String>> getErrorLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_errorLogKey) ?? [];
    } catch (e) {
      debugPrint('Failed to retrieve error logs: $e');
      return [];
    }
  }
  
  /// Clear all error logs
  static Future<void> clearErrorLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_errorLogKey);
    } catch (e) {
      debugPrint('Failed to clear error logs: $e');
    }
  }
}