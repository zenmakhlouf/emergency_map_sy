import 'package:bloc/bloc.dart';
import 'package:meta/meta.dart';
import '../models/report.dart';
import '../repo/reportRepoService.dart';

part 'reports_state.dart';

class ReportsCubit extends Cubit<ReportsState> {
  ReportsCubit(this._service) : super(ReportsInitial());

  final ReportService _service;

  Future<void> fetchReports({Map<String, dynamic>? query}) async {
    emit(ReportsLoading());
    try {
      final rawReports = await _service.fetchReports(query: query);
      final validReports = _filterValidReports(rawReports);
      
      if (validReports.isEmpty) {
        emit(ReportsEmpty());
      } else {
        emit(ReportsSuccess(validReports));
      }
    } catch (e) {
      emit(ReportsFailure(e.toString()));
    }
  }

  /// Filters out reports with missing crucial elements
  List<ReportEntity> _filterValidReports(List<ReportEntity> reports) {
    return reports.where((report) {
      // Check if state is null
      if (report.state == null) {
        return false;
      }
      
      // Check if emergency type is missing
      if (report.state!.emergencyType == null || 
          report.state!.emergencyType!.trim().isEmpty) {
        return false;
      }
      
      // Check if location is valid
      if (report.location.latitude == 0 && report.location.longitude == 0) {
        return false;
      }
      
      // Check if report details are completely missing
      if (report.state!.report == null || 
          (report.state!.report!.name == null && 
           report.state!.report!.description == null && 
           report.state!.report!.text == null)) {
        return false;
      }
      
      return true;
    }).toList();
  }

  /// Updates the status of a report and optimistically removes it from the list.
  Future<void> updateReportStatus(int reportId, String status) async {
    if (state is! ReportsSuccess) return;

    final currentState = state as ReportsSuccess;
    final originalReports = List<ReportEntity>.from(currentState.reports);

    try {
      // Optimistically remove the report from the UI, as both 'closed' and
      // 'deleted-closed' will result in it disappearing from the active list.
      final updatedReports =
          originalReports.where((r) => r.id != reportId).toList();

      if (updatedReports.isEmpty) {
        emit(ReportsEmpty());
      } else {
        emit(ReportsSuccess(updatedReports));
      }

      // Call the API to update the status in the backend.
      await _service.updateReportStatus(reportId: reportId, status: status);
    } catch (e) {
      // If the API call fails, revert the state to the original list and
      // emit a failure state so the user can be notified.
      emit(ReportsFailure(e.toString()));
      emit(ReportsSuccess(originalReports));
    }
  }
}
