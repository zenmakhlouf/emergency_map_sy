part of 'reports_cubit.dart';

@immutable
sealed class ReportsState {}

final class ReportsInitial extends ReportsState {}

final class ReportsLoading extends ReportsState {}

final class ReportsEmpty extends ReportsState {}

final class ReportsSuccess extends ReportsState {
  final List<ReportEntity> reports;
  ReportsSuccess(this.reports);
}

final class ReportsFailure extends ReportsState {
  final String message;
  ReportsFailure(this.message);
}
