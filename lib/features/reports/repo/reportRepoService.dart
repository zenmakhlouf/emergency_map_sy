import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../apis/network.dart';
import '../../../utils/urls.dart';
import '../models/report.dart';

class ReportService {
  Future<List<ReportEntity>> fetchReports({Map<String, dynamic>? query}) async {
    try {
      final Response response =
          await Network.getData(url: Urls.reports, queryParams: query);
      final dynamic body = response.data;

      List<dynamic> reportsListDynamic = <dynamic>[];
      if (body is Map<String, dynamic>) {
        final dynamic data = body['data'];
        final dynamic reports =
            (data is Map<String, dynamic>) ? data['reports'] : body['reports'];
        if (reports is List) {
          reportsListDynamic = reports;
        } else if (reports is Map) {
          reportsListDynamic = reports.values.toList();
          debugPrint('[reports] Converted map reports to list of values.');
        } else if (data is List) {
          reportsListDynamic = data;
          debugPrint('[reports] Used data as list directly.');
        } else if (body['reports'] is List) {
          reportsListDynamic = body['reports'] as List;
        } else {
          debugPrint(
              '[reports] Unexpected payload shape; defaulting to empty list.');
        }
      } else if (body is List) {
        reportsListDynamic = body;
      } else {
        debugPrint('[reports] Unknown response body type: ${body.runtimeType}');
      }

      final List<ReportEntity> reports = <ReportEntity>[];
      for (final dynamic item in reportsListDynamic) {
        if (item is Map<String, dynamic>) {
          try {
            reports.add(ReportEntity.fromJson(item));
          } catch (e) {
            debugPrint('[reports] Bad report item skipped: $e');
          }
        } else {
          debugPrint(
              '[reports] Non-map report item skipped: ${item.runtimeType}');
        }
      }
      return reports;
    } catch (e) {
      debugPrint('[reports] fetchReports error: $e');
      rethrow;
    }
  }

  Future<void> updateReportStatus({
    required int reportId,
    required String status,
  }) async {
    try {
      final formData = FormData.fromMap({
        'status': status,
      });

      final url = '${Urls.reports}/$reportId/status';

      await Network.postData(
        url: url,
        body: formData,
      );
    } catch (e) {
      debugPrint('[reports] updateReportStatus error: $e');
      rethrow;
    }
  }
}
