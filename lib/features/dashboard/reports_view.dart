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
              Text('All Reports',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w600)),
              if (lastSuccessfulRefresh != null)
                Text(
                  'Last updated: ${formatTime(lastSuccessfulRefresh!)}',
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
              hintText: 'Search reports...',
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
                  label: 'Category',
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
                  label: 'Status',
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
                    label: const Text('Clear'),
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
        PopupMenuItem(value: "All", child: Text('All ${label}s')),
        ...options.map((option) =>
            PopupMenuItem(value: option, child: Text(option.toUpperCase()))),
      ],
      child: Chip(
        avatar: Icon(
            selectedValue != null
                ? Icons.filter_alt
                : Icons.filter_alt_outlined,
            size: 16),
        label: Text(selectedValue != null
            ? '$label: ${selectedValue!.toUpperCase()}'
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

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onSelected,
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'distance', child: Text('DISTANCE')),
        const PopupMenuItem(value: 'date', child: Text('DATE')),
        const PopupMenuItem(value: 'priority', child: Text('PRIORITY')),
      ],
      child: Chip(
        avatar: Icon(sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
            size: 16),
        label: Text('Sort: ${sortBy.toUpperCase()}'),
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
    switch (userType) {
      case UserType.citizen:
        return _buildCitizenCard();
      case UserType.responder:
        return _buildResponderCard(context);
      case UserType.coordinator:
        return _buildCoordinatorCard();
    }
  }

  Widget _buildCitizenCard() {
    final reportName = report.state?.report
            ?.split('\n')
            .firstWhere((line) => line.startsWith('🚨') || line.contains('نوع'),
                orElse: () => report.title)
            .replaceAll(RegExp(r'^🚨[^:]*:?\s*'), '') ??
        report.title;
    final emergencyType = report.state?.emergencyType;
    final severity = report.state?.severity ?? 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: getColorForEmergencyType(emergencyType)
                        .withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    getIconForEmergencyType(emergencyType),
                    color: getColorForEmergencyType(emergencyType),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(reportName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined,
                              size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(formatShortAddress(report.fullAddress),
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                          Text('${distance.toStringAsFixed(1)} km',
                              style: TextStyle(
                                  color: Colors.grey[500], fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
                if (severity >= 0.7)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: severity >= 0.8 ? Colors.red : Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResponderCard(BuildContext context) {
    final emergencyType = report.state?.emergencyType;
    final severity = report.state?.severity ?? 0.0;
    final isAssigned =
        report.state?.assigned == context.read<AuthCubit>().userId;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Card(
        elevation: isActiveAssignment ? 4 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isActiveAssignment
              ? BorderSide(color: Colors.blue.shade300, width: 2)
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  _IncidentIcon(emergencyType: emergencyType),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                            child: Text(report.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 16),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis)),
                        _SeverityIndicator(severity: severity),
                      ]),
                      const SizedBox(height: 4),
                      Text(
                          '${report.state?.emergencySubType ?? 'غير محدد'} • ${report.formattedTime}',
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 13)),
                    ],
                  )),
                ]),
                const SizedBox(height: 8),
                Text(formatShortAddress(report.fullAddress),
                    style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                      child: Row(
                    children: [
                      Icon(Icons.near_me, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text('${distance.toStringAsFixed(1)} km away',
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 12)),
                      if (isAssigned) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(8)),
                          child: Text('ASSIGNED',
                              style: TextStyle(
                                  color: Colors.blue.shade700,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ],
                  )),
                  _QuickActions(onLocateOnMap: onLocateOnMap, onChat: onChat),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCoordinatorCard() {
    final emergencyType = report.state?.emergencyType;
    final severity = report.state?.severity ?? 0.0;
    final assignedUserId = report.state?.assigned;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color:
                      getColorForEmergencyType(emergencyType).withOpacity(0.05),
                  borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12)),
                ),
                child: Row(children: [
                  _IncidentIcon(emergencyType: emergencyType),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                            child: Text(
                                'Report #${report.id} • ${report.title}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 16),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis)),
                        _SeverityIndicator(severity: severity),
                      ]),
                      const SizedBox(height: 4),
                      Text(
                          'Type: ${report.state?.emergencySubType ?? 'Unspecified'} • ${report.formattedTime}',
                          style:
                              TextStyle(color: Colors.grey[700], fontSize: 13)),
                    ],
                  )),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (report.description.isNotEmpty &&
                        report.description != 'No description')
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(report.description,
                            style: TextStyle(
                                color: Colors.grey[800],
                                fontSize: 14,
                                height: 1.4),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis),
                      ),
                    Row(children: [
                      Icon(Icons.location_on,
                          size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(formatShortAddress(report.fullAddress),
                              style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500))),
                      Text('${distance.toStringAsFixed(1)} km',
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 13)),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                          child: Row(children: [
                        Icon(
                          assignedUserId != null && assignedUserId > 0
                              ? Icons.assignment_ind
                              : Icons.person_outline,
                          size: 16,
                          color: assignedUserId != null && assignedUserId > 0
                              ? Colors.green[600]
                              : Colors.grey[600],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          assignedUserId != null && assignedUserId > 0
                              ? 'Assigned to: User #$assignedUserId'
                              : 'Unassigned',
                          style: TextStyle(
                            color: assignedUserId != null && assignedUserId > 0
                                ? Colors.green[700]
                                : Colors.grey[600],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ])),
                      _QuickActions(
                          onLocateOnMap: onLocateOnMap, onChat: onChat),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
      label = 'HIGH';
    } else if (severity >= 0.6) {
      color = Colors.orange;
      label = 'MED';
    } else {
      color = Colors.yellow.shade700;
      label = 'LOW';
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
          tooltip: 'View on Map',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
        if (onChat != null)
          IconButton(
            icon: const Icon(Icons.chat, size: 20),
            onPressed: onChat,
            tooltip: 'Chat',
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
              hasFilters ? 'No Results' : 'All Clear',
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
                  ? 'No incidents match your filters'
                  : 'No incidents found',
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
        Text('Updating...',
            style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ]);
    }

    if (networkError != null) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.signal_wifi_off, size: 14, color: Colors.orange[700]),
        const SizedBox(width: 4),
        Text('Offline',
            style: TextStyle(fontSize: 12, color: Colors.orange[700])),
      ]);
    }

    if (lastSuccessfulRefresh != null) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.check_circle, size: 14, color: Colors.green[600]),
        const SizedBox(width: 4),
        Text('Live', style: TextStyle(fontSize: 12, color: Colors.green[600])),
      ]);
    }

    return const SizedBox.shrink();
  }
}
