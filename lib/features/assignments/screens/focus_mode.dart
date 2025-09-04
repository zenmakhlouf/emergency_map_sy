import 'package:emergency_map_sy/features/assignments/models/participation_request.dart';
import 'package:flutter/material.dart';

class FocusModeScreen extends StatelessWidget {
  final ParticipationRequest? activeRequest;
  
  const FocusModeScreen({
    super.key,
    this.activeRequest,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('وضع التركيز'),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.center_focus_strong,
              size: 100,
              color: Colors.green[600],
            ),
            const SizedBox(height: 24),
            Text(
              'Focus Mode',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.green[800],
              ),
            ),
            const SizedBox(height: 16),
            if (activeRequest != null) ...[
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Column(
                  children: [
                    Text(
                      'مهمة نشطة',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'طلب رقم: #${activeRequest!.id}',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.green[700],
                      ),
                    ),
                    Text(
                      'بلاغ رقم: #${activeRequest!.report.id}',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            Text(
              'هذا الشاشة ستحتوي على واجهة المستجيب\nأثناء تنفيذ المهمة',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// You'll need to import this in your participation_request.dart file
// For now, I'll assume ParticipationRequest is available