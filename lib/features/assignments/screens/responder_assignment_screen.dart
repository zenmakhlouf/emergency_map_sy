import 'package:emergency_map_sy/features/assignments/screens/focus_mode.dart';
import 'package:emergency_map_sy/features/assignments/screens/mock_request.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/assignments_cubit.dart';
import '../models/participation_request.dart';

class ResponderAssignmentScreen extends StatefulWidget {
  const ResponderAssignmentScreen({super.key});

  @override
  State<ResponderAssignmentScreen> createState() =>
      _ResponderAssignmentScreenState();
}

class _ResponderAssignmentScreenState extends State<ResponderAssignmentScreen> {
  @override
  void initState() {
    super.initState();
    // Cubit automatically starts polling when created
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('طلبات الاستجابة'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        actions: [
          // Mock request button for testing (remove when backend is fixed)
          MockRequestButton(),
          BlocBuilder<AssignmentsCubit, AssignmentsState>(
            builder: (context, state) {
              return IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: state is AssignmentsLoading
                    ? null
                    : () => context.read<AssignmentsCubit>().refresh(),
                tooltip: 'تحديث',
              );
            },
          ),
        ],
      ),
      body: BlocListener<AssignmentsCubit, AssignmentsState>(
        listener: (context, state) {
          // Handle focus mode navigation
          if (state is AssignmentsLoaded && state.acceptedRequests.isNotEmpty) {
            // Navigate to focus mode if there's an accepted request
            final activeRequest = state.acceptedRequests.first;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) =>
                      FocusModeScreen(activeRequest: activeRequest),
                ),
              );
            });
            return;
          }

          // Handle success/error states
          if (state is AssignmentActionSuccess) {
            // Close any open dialogs
            _dismissLoadingDialog();

            // Show success message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );

            // Check if the action was accepting a request - if so, navigate to focus mode
            if (state.action == 'accept' && state.updatedRequest.isAccepted) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) =>
                        FocusModeScreen(activeRequest: state.updatedRequest),
                  ),
                );
              });
            }
          } else if (state is AssignmentsError &&
              state.operation != 'load_all_assignments') {
            // Close any open dialogs
            _dismissLoadingDialog();

            // Show error message for operations (not loading)
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        },
        child: BlocBuilder<AssignmentsCubit, AssignmentsState>(
          builder: (context, state) {
            return _buildBody(context, state);
          },
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, AssignmentsState state) {
    if (state is AssignmentsLoading &&
        state.operation == 'loading_assignments') {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'جاري تحميل الطلبات...',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (state is AssignmentsError &&
        state.operation == 'load_all_assignments') {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[400],
            ),
            const SizedBox(height: 16),
            Text(
              'حدث خطأ في تحميل الطلبات',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red[700],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                state.message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => context.read<AssignmentsCubit>().refresh(),
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }

    if (state is AssignmentsEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.assignment_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد طلبات استجابة',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ستظهر هنا طلبات الاستجابة للحالات الطارئة',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (state is AssignmentsLoaded) {
      final pendingRequests = state.pendingRequests;
      final acceptedRequests = state.acceptedRequests;

      return RefreshIndicator(
        onRefresh: () => context.read<AssignmentsCubit>().refresh(),
        child: CustomScrollView(
          slivers: [
            // Pending requests section
            if (pendingRequests.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(Icons.pending_actions, color: Colors.orange[700]),
                      const SizedBox(width: 8),
                      Text(
                        'طلبات قيد الانتظار (${pendingRequests.length})',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final request = pendingRequests[index];
                    return _buildPendingRequestCard(context, request);
                  },
                  childCount: pendingRequests.length,
                ),
              ),
            ],

            // Accepted requests section
            if (acceptedRequests.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(top: 16),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green[700]),
                      const SizedBox(width: 8),
                      Text(
                        'المهام المقبولة (${acceptedRequests.length})',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final request = acceptedRequests[index];
                    return _buildAcceptedRequestCard(context, request);
                  },
                  childCount: acceptedRequests.length,
                ),
              ),
            ],

            // Empty state if no requests
            if (pendingRequests.isEmpty && acceptedRequests.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.assignment_outlined,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'لا توجد مهام حالياً',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildPendingRequestCard(
      BuildContext context, ParticipationRequest request) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with status
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.pending_actions,
                            size: 16, color: Colors.orange[700]),
                        const SizedBox(width: 4),
                        Text(
                          request.statusDisplayName,
                          style: TextStyle(
                            color: Colors.orange[700],
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'طلب رقم #${request.id}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Report information
              _buildReportInfo(request.report),

              const SizedBox(height: 16),

              // Initiator information
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'طلب من: ${request.initiator.name}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _acceptRequest(context, request),
                      icon: const Icon(Icons.check, color: Colors.white),
                      label: const Text(
                        'قبول المهمة',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _rejectRequest(context, request),
                      icon: Icon(Icons.close, color: Colors.red[600]),
                      label: Text(
                        'رفض',
                        style: TextStyle(
                            color: Colors.red[600],
                            fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.red[600]!),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAcceptedRequestCard(
      BuildContext context, ParticipationRequest request) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with status
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle,
                            size: 16, color: Colors.green[700]),
                        const SizedBox(width: 4),
                        Text(
                          request.statusDisplayName,
                          style: TextStyle(
                            color: Colors.green[700],
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'مهمة #${request.id}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Report information
              _buildReportInfo(request.report),

              const SizedBox(height: 16),

              // Cancel button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _cancelRequest(context, request),
                  icon: Icon(Icons.cancel, color: Colors.grey[700]),
                  label: Text(
                    'إلغاء المهمة',
                    style: TextStyle(
                        color: Colors.grey[700], fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey[400]!),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportInfo(EmergencyReport report) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Report header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.red[600],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.emergency,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'بلاغ طوارئ #${report.id}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.red[800],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.person, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          'بلغ من: ${report.initiator.name}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Status
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _getStatusColor(report.latestStatus.statusColor),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                report.latestStatus.statusDisplay,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _getStatusColor(report.latestStatus.statusColor),
                ),
              ),
              const Spacer(),
              Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                _formatDateTime(report.createdAt),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),

          if (report.latestStatus.notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.note, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      report.latestStatus.notes,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getStatusColor(String statusColor) {
    switch (statusColor.toLowerCase()) {
      case 'blue':
        return Colors.blue;
      case 'red':
        return Colors.red;
      case 'green':
        return Colors.green;
      case 'orange':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} يوم مضى';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ساعة مضت';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} دقيقة مضت';
    } else {
      return 'الآن';
    }
  }

  void _acceptRequest(BuildContext context, ParticipationRequest request) {
    _showLoadingDialog();

    context.read<AssignmentsCubit>().acceptParticipationRequest(
          reportId: request.report.id,
          responderId: request.responder.id,
        );
  }

  void _rejectRequest(BuildContext context, ParticipationRequest request) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('رفض الطلب'),
        content: const Text(
            'هل أنت متأكد من رفض طلب الاستجابة لهذه الحالة الطارئة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);

              _showLoadingDialog();

              context.read<AssignmentsCubit>().rejectParticipationRequest(
                    reportId: request.report.id,
                    responderId: request.responder.id,
                  );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('رفض'),
          ),
        ],
      ),
    );
  }

  void _cancelRequest(BuildContext context, ParticipationRequest request) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إلغاء المهمة'),
        content: const Text('هل أنت متأكد من إلغاء هذه المهمة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('لا'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);

              _showLoadingDialog();

              context.read<AssignmentsCubit>().cancelParticipationRequest(
                    reportId: request.report.id,
                    responderId: request.responder.id,
                  );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('نعم، إلغاء'),
          ),
        ],
      ),
    );
  }

  // Helper methods for loading dialog management
  void _showLoadingDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  void _dismissLoadingDialog() {
    if (!mounted) return;

    // Only pop if there's actually a dialog to pop
    if (Navigator.canPop(context)) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }
}
