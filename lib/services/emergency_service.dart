import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/emergency_report.dart';

class EmergencyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<EmergencyReport>> getActiveReports() {
    return _firestore
        .collection('emergencies')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => EmergencyReport.fromFirestore(doc))
          .toList();
    });
  }

  Future<void> addReport(EmergencyReport report) {
    return _firestore.collection('emergencies').add(report.toFirestore());
  }

  Future<void> volunteerForEmergency(String reportId, String userId) {
    return _firestore.collection('emergencies').doc(reportId).update({
      'volunteers': FieldValue.arrayUnion([userId]),
    });
  }
}
