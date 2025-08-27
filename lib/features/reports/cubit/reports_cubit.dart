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
}
