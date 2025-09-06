import 'package:flutter/material.dart';
import '../../features/reports/models/report.dart';
import '../../features/auth/models/user_type.dart';
import 'package:latlong2/latlong.dart';
import 'helpers.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../features/auth/cubit/auth_cubit.dart';

// ============================================================================
// MAIN REPORTS TAB WIDGET
// ============================================================================

class ReportsTabView extends StatelessWidget {
  // Data
  final List<ReportEntity> reports;
  final ReportEntity? activeAssignment;
  final LatLng currentPosition;

  // Filter & Search State
  final String searchQuery;
  final String? selectedCategory;
  final String? selectedStatus;
  final String sortBy;
  final bool sortAscending;

  // UI State
  final bool isRefreshing;
  final DateTime? lastSuccessfulRefresh;
  final String? networkError;
  final UserType userType;

  // Callbacks
  final Future<void> Function() onRefresh;
  final Function(String) onSearchChanged;
  final Function(String) onCategorySelected;
  final Function(String) onStatusSelected;
  final Function(String) onSortSelected;
  final VoidCallback onClearFilters;
  final Function(ReportEntity) onReportTap;
  final Function(ReportEntity) onLocateOnMap;
  final Function(ReportEntity) onChat;

  const ReportsTabView({
    super.key,
    required this.reports,
    this.activeAssignment,
    required this.currentPosition,
    required this.searchQuery,
    this.selectedCategory,
    this.selectedStatus,
    required this.sortBy,
    required this.sortAscending,
    required this.isRefreshing,
    this.lastSuccessfulRefresh,
    this.networkError,
    required this.userType,
    required this.onRefresh,
    required this.onSearchChanged,
    required this.onCategorySelected,
    required this.onStatusSelected,
    required this.onSortSelected,
    required this.onClearFilters,
    required this.onReportTap,
    required this.onLocateOnMap,
    required this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: Column(
        children: [
          _ReportsHeader(
            lastSuccessfulRefresh: lastSuccessfulRefresh,
            networkError: networkError,
            isRefreshing: isRefreshing,
          ),
          _SearchAndFiltersBar(
            searchQuery: searchQuery,
            selectedCategory: selectedCategory,
            selectedStatus: selectedStatus,
            sortBy: sortBy,
            sortAscending: sortAscending,
            onSearchChanged: onSearchChanged,
            onCategorySelected: onCategorySelected,
            onStatusSelected: onStatusSelected,
            onSortSelected: onSortSelected,
            onClearFilters: onClearFilters,
          ),
          Expanded(child: _buildContent(context)),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (reports.isEmpty && !isRefreshing) {
      bool hasFilters = searchQuery.isNotEmpty ||
          selectedCategory != null ||
          selectedStatus != null;
      return _EmptyState(hasFilters: hasFilters);
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: reports.length,
      itemBuilder: (context, index) {
        final report = reports[index];
        final distance = calculateDistance(
            currentPosition, LatLng(report.latitude, report.longitude));
        return ReportCard(
          report: report,
          distance: distance,
          userType: userType,
          isActiveAssignment: activeAssignment?.id == report.id,
          onTap: () => onReportTap(report),
          onLocateOnMap: () => onLocateOnMap(report),
          onChat: _canAccessReportChat(context, report)
              ? () => onChat(report)
              : null,
        );
      },
    );
  }

  bool _canAccessReportChat(BuildContext context, ReportEntity report) {
    final authCubit = context.read<AuthCubit>();
    final currentUserId = authCubit.userId;
    if (currentUserId == null) return false;
    if (userType == UserType.coordinator) return true;
    if (userType == UserType.citizen)
      return report.initiatorId == currentUserId;
    if (userType == UserType.responder) {
      return report.initiatorId == currentUserId ||
          report.state?.assigned == currentUserId ||
          activeAssignment?.id == report.id;
    }
    return false;
  }
}

// ============================================================================
// HEADER & FILTER COMPONENTS
// ============================================================================

class _ReportsHeader extends StatelessWidget {
  final DateTime? lastSuccessfulRefresh;
  final String? networkError;
  final bool isRefreshing;

  const _ReportsHeader(
      {this.lastSuccessfulRefresh,
      this.networkError,
      required this.isRefreshing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
            bottom: BorderSide(
                color: Theme.of(context).dividerColor.withOpacity(0.3))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('كل البلاغات',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w600)),
              if (lastSuccessfulRefresh != null)
                Text(
                  'آخر تحديث: ${formatTime(lastSuccessfulRefresh!)}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey[600]),
                ),
            ],
          ),
          _NetworkStatusIndicator(
              isRefreshing: isRefreshing,
              networkError: networkError,
              lastSuccessfulRefresh: lastSuccessfulRefresh),
        ],
      ),
    );
  }
}

class _SearchAndFiltersBar extends StatelessWidget {
  final String searchQuery;
  final String? selectedCategory;
  final String? selectedStatus;
  final String sortBy;
  final bool sortAscending;
  final Function(String) onSearchChanged;
  final Function(String) onCategorySelected;
  final Function(String) onStatusSelected;
  final Function(String) onSortSelected;
  final VoidCallback onClearFilters;

  const _SearchAndFiltersBar({
    required this.searchQuery,
    this.selectedCategory,
    this.selectedStatus,
    required this.sortBy,
    required this.sortAscending,
    required this.onSearchChanged,
    required this.onCategorySelected,
    required this.onStatusSelected,
    required this.onSortSelected,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    final searchController = TextEditingController(text: searchQuery);
    searchController.selection = TextSelection.fromPosition(
        TextPosition(offset: searchController.text.length));

    bool hasFilters = selectedCategory != null ||
        selectedStatus != null ||
        searchQuery.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        children: [
          TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: 'ابحث في البلاغات...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => onSearchChanged(""),
                    )
                  : null,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: 'الفئة',
                  selectedValue: selectedCategory,
                  options: const [
                    'medical',
                    'fire',
                    'police',
                    'traffic',
                    'other'
                  ],
                  onSelected: onCategorySelected,
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'الحالة',
                  selectedValue: selectedStatus,
                  options: const [
                    'pending',
                    'assigned',
                    'in_progress',
                    'resolved',
                    'closed'
                  ],
                  onSelected: onStatusSelected,
                ),
                const SizedBox(width: 8),
                _SortChip(
                  sortBy: sortBy,
                  sortAscending: sortAscending,
                  onSelected: onSortSelected,
                ),
                if (hasFilters) ...[
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(Icons.clear, size: 16),
                    label: const Text('مسح الفلاتر'),
                    onPressed: onClearFilters,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Helper function to translate filter option values for display
String _translateFilterOption(String option) {
  switch (option.toLowerCase()) {
    // Categories
    case 'medical':
      return 'طبي';
    case 'fire':
      return 'حريق';
    case 'police':
      return 'أمني';
    case 'traffic':
      return 'مروري';
    case 'other':
      return 'أخرى';
    // Statuses
    case 'pending':
      return 'قيد الانتظار';
    case 'assigned':
      return 'مُكلف';
    case 'in_progress':
      return 'قيد التنفيذ';
    case 'resolved':
      return 'تم الحل';
    case 'closed':
      return 'مغلق';
    default:
      return option;
  }
}

// Helper function for grammatically correct "All" text
String _getAllTextForLabel(String label) {
  switch (label) {
    case 'الفئة':
      return 'كل الفئات';
    case 'الحالة':
      return 'كل الحالات';
    default:
      return 'الكل';
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String? selectedValue;
  final List<String> options;
  final Function(String) onSelected;

  const _FilterChip(
      {required this.label,
      this.selectedValue,
      required this.options,
      required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onSelected,
      itemBuilder: (context) => [
        PopupMenuItem(value: "All", child: Text(_getAllTextForLabel(label))),
        ...options.map((option) => PopupMenuItem(
            value: option, child: Text(_translateFilterOption(option)))),
      ],
      child: Chip(
        avatar: Icon(
            selectedValue != null
                ? Icons.filter_alt
                : Icons.filter_alt_outlined,
            size: 16),
        label: Text(selectedValue != null
            ? '$label: ${_translateFilterOption(selectedValue!)}'
            : label),
        backgroundColor:
            selectedValue != null ? Colors.blue.shade100 : Colors.grey.shade100,
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  final String sortBy;
  final bool sortAscending;
  final Function(String) onSelected;

  const _SortChip(
      {required this.sortBy,
      required this.sortAscending,
      required this.onSelected});

  String _translateSortOption(String option) {
    switch (option.toLowerCase()) {
      case 'distance':
        return 'المسافة';
      case 'date':
        return 'التاريخ';
      case 'priority':
        return 'الأولوية';
      default:
        return option;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onSelected,
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'distance', child: Text('المسافة')),
        const PopupMenuItem(value: 'date', child: Text('التاريخ')),
        const PopupMenuItem(value: 'priority', child: Text('الأولوية')),
      ],
      child: Chip(
        avatar: Icon(sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
            size: 16),
        label: Text('ترتيب حسب: ${_translateSortOption(sortBy)}'),
        backgroundColor: Colors.green.shade100,
      ),
    );
  }
}

// ============================================================================
// INDIVIDUAL REPORT CARD WIDGET
// ============================================================================

class ReportCard extends StatelessWidget {
  final ReportEntity report;
  final double distance;
  final UserType userType;
  final bool isActiveAssignment;
  final VoidCallback onTap;
  final VoidCallback onLocateOnMap;
  final VoidCallback? onChat;

  const ReportCard({
    super.key,
    required this.report,
    required this.distance,
    required this.userType,
    required this.isActiveAssignment,
    required this.onTap,
    required this.onLocateOnMap,
    this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    // The Directionality widget is crucial for ensuring the card's layout is RTL
    return Directionality(
      textDirection: TextDirection.rtl,
      child: _buildCompactCard(context),
    );
  }

  Widget _buildCompactCard(BuildContext context) {
    final reportDetails = report.state?.report;
    final reportName = reportDetails?.name?.trim() ??
        _getEmergencyTypeArabic(report.state?.emergencyType);
    final description = reportDetails?.description?.trim() ??
        reportDetails?.text
            ?.split('\n')
            .where((line) =>
                line.trim().isNotEmpty &&
                !line.startsWith('🚨') &&
                !line.startsWith('⚠️') &&
                !line.startsWith('📝'))
            .join(' ')
            .trim();
    final emergencyType = report.state?.emergencyType;
    final subType = _getEmergencySubTypeArabic(report.state?.emergencySubType);
    final severity = report.state?.severity ?? 0.0;
    final severityColor = _getSeverityColor(severity);
    final emergencyColor = getColorForEmergencyType(emergencyType);
    final isAssigned =
        report.state?.assigned != null && report.state!.assigned! > 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        elevation: isActiveAssignment ? 3 : 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: isActiveAssignment
                  ? Border.all(color: Colors.blue.shade400, width: 2)
                  : Border.all(color: emergencyColor.withOpacity(0.2)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row with icon, title info, and severity
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: emergencyColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: emergencyColor.withOpacity(0.3)),
                        ),
                        child: Icon(
                          getIconForEmergencyType(emergencyType),
                          color: emergencyColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Report name
                            Text(
                              reportName,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: emergencyColor,
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            // Subtype and time
                            Row(
                              children: [
                                Text(
                                  subType,
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  ' • ${report.formattedTime}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Severity badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: severityColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: severityColor.withOpacity(0.5)),
                        ),
                        child: Text(
                          _getSeverityLabel(severity),
                          style: TextStyle(
                            color: severityColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Description (if available and not empty)
                  if (description != null && description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.3,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(height: 8),

                  // Distance row
                  Row(
                    children: [
                      Icon(Icons.near_me_outlined,
                          size: 14, color: Colors.blue.shade600),
                      const SizedBox(width: 4),
                      Text(
                        '${distance.toStringAsFixed(1)} كم من موقعك',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Status and actions row
                  Row(
                    children: [
                      // Assignment status (for coordinators and responders)
                      if (userType != UserType.citizen && isAssigned) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.assignment_turned_in,
                                  size: 12, color: Colors.green.shade700),
                              const SizedBox(width: 3),
                              Text(
                                'مُكلف',
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],

                      // Participation requests
                      if (report.participationRequests.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.people,
                                  size: 12, color: Colors.orange.shade700),
                              const SizedBox(width: 3),
                              Text(
                                '${report.participationRequests.length}',
                                style: TextStyle(
                                  color: Colors.orange.shade700,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],

                      // Active assignment indicator
                      if (isActiveAssignment) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade600,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'مهمة نشطة',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],

                      const Spacer(),

                      // Action buttons
                      IconButton(
                        icon: const Icon(Icons.map_outlined, size: 18),
                        onPressed: onLocateOnMap,
                        tooltip: 'عرض على الخريطة',
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 28, minHeight: 28),
                        color: Colors.blue.shade600,
                      ),
                      if (onChat != null)
                        IconButton(
                          icon: const Icon(Icons.chat_bubble_outline, size: 18),
                          onPressed: onChat,
                          tooltip: 'الدردشة',
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 28, minHeight: 28),
                          color: Colors.green.shade600,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getEmergencyTypeArabic(String? type) {
    switch (type?.toUpperCase()) {
      case 'MEDICAL':
        return 'حالة طبية';
      case 'FIRE':
        return 'حريق';
      case 'POLICE':
        return 'حالة أمنية';
      case 'CIVIL':
        return 'حالة مدنية';
      case 'TRAFFIC':
        return 'حادث مروري';
      default:
        return 'بلاغ طوارئ';
    }
  }

  String _getEmergencySubTypeArabic(String? subType) {
    switch (subType?.toLowerCase()) {
      case 'theft':
        return 'سرقة';
      case 'murder':
        return 'قتل';
      case 'body':
        return 'جثة';
      case 'structure_fire':
        return 'حريق مبنى';
      case 'major_accident':
        return 'حادث كبير';
      case 'complaint':
        return 'شكوى';
      case 'warning':
        return 'تحذير';
      case 'explosion':
        return 'انفجار';
      case 'violent_crime':
        return 'جريمة عنف';
      case 'fight':
        return 'شجار';
      case 'unknown_fire':
        return 'حريق';
      default:
        return subType ?? 'غير محدد';
    }
  }

  Color _getSeverityColor(double severity) {
    if (severity >= 0.8) return Colors.red.shade600;
    if (severity >= 0.6) return Colors.orange.shade600;
    return Colors.green.shade600;
  }

  String _getSeverityLabel(double severity) {
    if (severity >= 0.8) return 'عالية';
    if (severity >= 0.6) return 'متوسطة';
    return 'منخفضة';
  }
}

// ============================================================================
// WIDGETS USED IN CARDS AND OTHER PLACES
// ============================================================================

class _IncidentIcon extends StatelessWidget {
  final String? emergencyType;
  const _IncidentIcon({this.emergencyType});

  @override
  Widget build(BuildContext context) {
    final color = getColorForEmergencyType(emergencyType);
    final icon = getIconForEmergencyType(emergencyType);
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }
}

class _SeverityIndicator extends StatelessWidget {
  final double severity;
  const _SeverityIndicator({required this.severity});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    if (severity >= 0.8) {
      color = Colors.red;
      label = 'عالية';
    } else if (severity >= 0.6) {
      color = Colors.orange;
      label = 'متوسطة';
    } else {
      color = Colors.yellow.shade700;
      label = 'منخفضة';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style:
            TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 11),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final VoidCallback onLocateOnMap;
  final VoidCallback? onChat;
  const _QuickActions({required this.onLocateOnMap, this.onChat});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.map, size: 20),
          onPressed: onLocateOnMap,
          tooltip: 'عرض على الخريطة',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
        if (onChat != null)
          IconButton(
            icon: const Icon(Icons.chat, size: 20),
            onPressed: onChat,
            tooltip: 'الدردشة',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasFilters;
  const _EmptyState({required this.hasFilters});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasFilters ? Icons.search_off : Icons.check_circle_outline,
              size: 64,
              color: hasFilters ? Colors.grey.shade400 : Colors.green.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              hasFilters ? 'لا توجد نتائج' : 'لا توجد بلاغات حالياً',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color:
                    hasFilters ? Colors.grey.shade600 : Colors.green.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasFilters
                  ? 'لا توجد بلاغات تطابق معايير البحث المحددة'
                  : 'لم يتم العثور على أي بلاغات',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _NetworkStatusIndicator extends StatelessWidget {
  final bool isRefreshing;
  final String? networkError;
  final DateTime? lastSuccessfulRefresh;

  const _NetworkStatusIndicator(
      {required this.isRefreshing,
      this.networkError,
      this.lastSuccessfulRefresh});

  @override
  Widget build(BuildContext context) {
    if (isRefreshing) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2)),
        const SizedBox(width: 8),
        Text('جاري التحديث...',
            style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ]);
    }

    if (networkError != null) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.signal_wifi_off, size: 14, color: Colors.orange[700]),
        const SizedBox(width: 4),
        Text('غير متصل',
            style: TextStyle(fontSize: 12, color: Colors.orange[700])),
      ]);
    }

    if (lastSuccessfulRefresh != null) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.check_circle, size: 14, color: Colors.green[600]),
        const SizedBox(width: 4),
        Text('مباشر', style: TextStyle(fontSize: 12, color: Colors.green[600])),
      ]);
    }

    return const SizedBox.shrink();
  }
}
