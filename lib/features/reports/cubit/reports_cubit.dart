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
      final reports = await _service.fetchReports(query: query);
      if (reports.isEmpty) {
        emit(ReportsEmpty());
      } else {
        emit(ReportsSuccess(reports));
      }
    } catch (e) {
      emit(ReportsFailure(e.toString()));
    }
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
