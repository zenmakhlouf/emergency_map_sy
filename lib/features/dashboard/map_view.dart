import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../features/auth/models/user_type.dart';
import '../../features/reports/models/report.dart';
import '../../features/users_location/repo/locationservice.dart';
import 'helpers.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../features/auth/cubit/auth_cubit.dart';

// ============================================================================
// MAIN MAP TAB WIDGET
// ============================================================================

class MapTabView extends StatelessWidget {
  // Map and Data State
  final MapController mapController;
  final UserType userType;
  final ReportEntity? activeAssignment;
  final LatLng currentPosition;
  final List<LatLng> routePolyline;
  final List<ReportEntity> reports;
  final List<UserLocationEntity> otherUsers;

  // UI State
  final bool isRouteLoading;
  final bool isRefreshing;
  final bool showReportMarkers;
  final bool showUserMarkers;
  final double defaultZoom;

  // Callbacks
  final Function(MapCamera, bool) onPositionChanged;
  final VoidCallback onRefresh;
  final VoidCallback onCenterMap;
  final VoidCallback onShowFilters;
  final Function(ReportEntity) onShowReportDetails;
  final Function(UserLocationEntity) onShowUserDetails;
  final Function(ReportEntity) onGetDirections;
  final VoidCallback onClearRoute;
  final Function(String) onUpdateAssignmentStatus;

  const MapTabView({
    super.key,
    required this.mapController,
    required this.userType,
    this.activeAssignment,
    required this.currentPosition,
    required this.routePolyline,
    required this.reports,
    required this.otherUsers,
    required this.isRouteLoading,
    required this.isRefreshing,
    required this.showReportMarkers,
    required this.showUserMarkers,
    required this.defaultZoom,
    required this.onPositionChanged,
    required this.onRefresh,
    required this.onCenterMap,
    required this.onShowFilters,
    required this.onShowReportDetails,
    required this.onShowUserDetails,
    required this.onGetDirections,
    required this.onClearRoute,
    required this.onUpdateAssignmentStatus,
  });

  @override
  Widget build(BuildContext context) {
    if (userType != UserType.citizen && activeAssignment != null) {
      return _ActiveAssignmentView(
        mapController: mapController,
        assignment: activeAssignment!,
        currentPosition: currentPosition,
        routePolyline: routePolyline,
        otherUsers: otherUsers,
        defaultZoom: defaultZoom,
        isRouteLoading: isRouteLoading,
        showUserMarkers: showUserMarkers,
        onPositionChanged: onPositionChanged,
        onGetDirections: onGetDirections,
        onClearRoute: onClearRoute,
        onUpdateStatus: onUpdateAssignmentStatus,
        onShowUserDetails: onShowUserDetails,
        onRefresh: onRefresh,
        isRefreshing: isRefreshing,
        onCenterMap: onCenterMap,
        onShowFilters: onShowFilters,
      );
    }

    return _ResponderMapView(
      mapController: mapController,
      currentPosition: currentPosition,
      routePolyline: routePolyline,
      reports: reports,
      otherUsers: otherUsers,
      activeAssignment: activeAssignment,
      userType: userType,
      defaultZoom: defaultZoom,
      showReportMarkers: showReportMarkers,
      showUserMarkers: showUserMarkers,
      onPositionChanged: onPositionChanged,
      onShowReportDetails: onShowReportDetails,
      onShowUserDetails: onShowUserDetails,
      onRefresh: onRefresh,
      isRefreshing: isRefreshing,
      onCenterMap: onCenterMap,
      onShowFilters: onShowFilters,
    );
  }
}

// ============================================================================
// MAP VIEWS (RESPONDER / ACTIVE ASSIGNMENT)
// ============================================================================

class _ResponderMapView extends StatelessWidget {
  final MapController mapController;
  final LatLng currentPosition;
  final List<LatLng> routePolyline;
  final List<ReportEntity> reports;
  final List<UserLocationEntity> otherUsers;
  final ReportEntity? activeAssignment;
  final UserType userType;
  final double defaultZoom;
  final bool showReportMarkers;
  final bool showUserMarkers;
  final Function(MapCamera, bool) onPositionChanged;
  final Function(ReportEntity) onShowReportDetails;
  final Function(UserLocationEntity) onShowUserDetails;
  final VoidCallback onRefresh;
  final bool isRefreshing;
  final VoidCallback onCenterMap;
  final VoidCallback onShowFilters;

  const _ResponderMapView({
    required this.mapController,
    required this.currentPosition,
    required this.routePolyline,
    required this.reports,
    required this.otherUsers,
    this.activeAssignment,
    required this.userType,
    required this.defaultZoom,
    required this.showReportMarkers,
    required this.showUserMarkers,
    required this.onPositionChanged,
    required this.onShowReportDetails,
    required this.onShowUserDetails,
    required this.onRefresh,
    required this.isRefreshing,
    required this.onCenterMap,
    required this.onShowFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: mapController,
          options: MapOptions(
            initialCenter: currentPosition,
            initialZoom: defaultZoom,
            minZoom: 1,
            maxZoom: 40,
            onPositionChanged: onPositionChanged,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.emergency.map',
            ),
            if (routePolyline.isNotEmpty)
              PolylineLayer(polylines: [_buildRoutePolyline()]),
            MarkerLayer(
              markers: _buildAllMapMarkers(context),
            ),
          ],
        ),
        _MapControls(
          onRefresh: onRefresh,
          isRefreshing: isRefreshing,
          onCenterMap: onCenterMap,
          onShowFilters: onShowFilters,
          onZoomIn: () => mapController.move(
              mapController.camera.center, mapController.camera.zoom + 1),
          onZoomOut: () => mapController.move(
              mapController.camera.center, mapController.camera.zoom - 1),
        ),
      ],
    );
  }

  Polyline _buildRoutePolyline() {
    return Polyline(
      points: routePolyline,
      strokeWidth: 5.0,
      color: Colors.deepPurpleAccent,
      borderStrokeWidth: 2.0,
      borderColor: Colors.white.withOpacity(0.8),
    );
  }

  List<Marker> _buildAllMapMarkers(BuildContext context) {
    return [
      _buildUserLocationMarker(context, currentPosition, userType.name),
      if (showReportMarkers) ..._buildReportMarkers(),
      if (showUserMarkers) ..._buildOtherUserMarkers(context),
    ];
  }

  List<Marker> _buildReportMarkers() {
    return reports.map((report) {
      final isActive = activeAssignment?.id == report.id;
      return Marker(
        width: isActive ? 50 : 40,
        height: isActive ? 50 : 40,
        alignment: Alignment.center,
        point: LatLng(report.latitude, report.longitude),
        child: GestureDetector(
          onTap: () => onShowReportDetails(report),
          child: Container(
            decoration: BoxDecoration(
              color: getColorForEmergencyType(report.state?.emergencyType),
              shape: BoxShape.circle,
              border: Border.all(
                  color: isActive ? Colors.yellow : Colors.white,
                  width: isActive ? 3 : 2),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Icon(getIconForEmergencyType(report.state?.emergencyType),
                color: Colors.white, size: isActive ? 28 : 24),
          ),
        ),
      );
    }).toList();
  }

  List<Marker> _buildOtherUserMarkers(BuildContext context) {
    final currentUserId = context.read<AuthCubit>().userId;
    return otherUsers
        .where((user) => user.id.toString() != currentUserId.toString())
        .map((user) => Marker(
              width: 25,
              height: 25,
              alignment: Alignment.center,
              point: LatLng(user.location!.lat, user.location!.lon),
              child: GestureDetector(
                onTap: () => onShowUserDetails(user),
                child: Container(
                  decoration: BoxDecoration(
                    color: getUserRoleColor(user.primaryRole),
                    shape: BoxShape.rectangle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 4,
                          offset: const Offset(0, 2))
                    ],
                  ),
                  child: Icon(getUserRoleIcon(user.primaryRole),
                      color: Colors.white, size: 20),
                ),
              ),
            ))
        .toList();
  }
}

class _ActiveAssignmentView extends StatelessWidget {
  final MapController mapController;
  final ReportEntity assignment;
  final LatLng currentPosition;
  final List<LatLng> routePolyline;
  final List<UserLocationEntity> otherUsers;
  final double defaultZoom;
  final bool isRouteLoading;
  final bool showUserMarkers;
  final Function(MapCamera, bool) onPositionChanged;
  final Function(ReportEntity) onGetDirections;
  final VoidCallback onClearRoute;
  final Function(String) onUpdateStatus;
  final Function(UserLocationEntity) onShowUserDetails;
  final VoidCallback onRefresh;
  final bool isRefreshing;
  final VoidCallback onCenterMap;
  final VoidCallback onShowFilters;

  const _ActiveAssignmentView({
    required this.mapController,
    required this.assignment,
    required this.currentPosition,
    required this.routePolyline,
    required this.otherUsers,
    required this.defaultZoom,
    required this.isRouteLoading,
    required this.showUserMarkers,
    required this.onPositionChanged,
    required this.onGetDirections,
    required this.onClearRoute,
    required this.onUpdateStatus,
    required this.onShowUserDetails,
    required this.onRefresh,
    required this.isRefreshing,
    required this.onCenterMap,
    required this.onShowFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ActiveAssignmentHeader(
            assignment: assignment, currentPosition: currentPosition),
        Expanded(
            child: Stack(
          children: [
            FlutterMap(
              mapController: mapController,
              options: MapOptions(
                initialCenter:
                    LatLng(assignment.latitude, assignment.longitude),
                initialZoom: defaultZoom,
                minZoom: 1,
                maxZoom: 40,
                onPositionChanged: onPositionChanged,
              ),
              children: [
                TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.emergency.map'),
                if (routePolyline.isNotEmpty)
                  PolylineLayer(polylines: [
                    Polyline(
                        points: routePolyline,
                        strokeWidth: 5.0,
                        color: Colors.deepPurpleAccent,
                        borderStrokeWidth: 2.0,
                        borderColor: Colors.white.withOpacity(0.8)),
                  ]),
                MarkerLayer(markers: _buildAssignmentMarkers(context)),
              ],
            ),
            _MapControls(
              onRefresh: onRefresh,
              isRefreshing: isRefreshing,
              onCenterMap: onCenterMap,
              onShowFilters: onShowFilters,
              onZoomIn: () => mapController.move(
                  mapController.camera.center, mapController.camera.zoom + 1),
              onZoomOut: () => mapController.move(
                  mapController.camera.center, mapController.camera.zoom - 1),
            ),
          ],
        )),
        _ActiveAssignmentActions(
          assignment: assignment,
          isRouteLoading: isRouteLoading,
          hasRoute: routePolyline.isNotEmpty,
          onGetDirections: () => onGetDirections(assignment),
          onClearRoute: onClearRoute,
          onUpdateStatus: onUpdateStatus,
        ),
      ],
    );
  }

  List<Marker> _buildAssignmentMarkers(BuildContext context) {
    final currentUserId = context.read<AuthCubit>().userId;
    return [
      _buildUserLocationMarker(context, currentPosition, 'responder'),
      Marker(
        width: 50,
        height: 50,
        alignment: Alignment.center,
        point: LatLng(assignment.latitude, assignment.longitude),
        child: Container(
          decoration: BoxDecoration(
            color: getColorForEmergencyType(assignment.state?.emergencyType),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 3))
            ],
          ),
          child: Icon(getIconForEmergencyType(assignment.state?.emergencyType),
              color: Colors.white, size: 28),
        ),
      ),
      if (showUserMarkers)
        ...otherUsers
            .where((user) => user.id.toString() != currentUserId.toString())
            .map((user) => Marker(
                  width: 25,
                  height: 25,
                  alignment: Alignment.center,
                  point: LatLng(user.location!.lat, user.location!.lon),
                  child: GestureDetector(
                    onTap: () => onShowUserDetails(user),
                    child: Container(
                      decoration: BoxDecoration(
                        color: getUserRoleColor(user.primaryRole),
                        shape: BoxShape.rectangle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 4,
                              offset: const Offset(0, 2))
                        ],
                      ),
                      child: Icon(getUserRoleIcon(user.primaryRole),
                          color: Colors.white, size: 20),
                    ),
                  ),
                ))
            .toList(),
    ];
  }
}

// ============================================================================
// UI HELPER COMPONENTS FOR MAP
// ============================================================================

Marker _buildUserLocationMarker(
    BuildContext context, LatLng position, String role) {
  return Marker(
    width: 30,
    height: 30,
    alignment: Alignment.center,
    point: position,
    child: Container(
      decoration: BoxDecoration(
        color: getUserRoleColor(role),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2))
        ],
      ),
      child: const Icon(Icons.person_pin_circle, color: Colors.white, size: 18),
    ),
  );
}

class _MapControls extends StatelessWidget {
  final VoidCallback onRefresh;
  final bool isRefreshing;
  final VoidCallback onCenterMap;
  final VoidCallback onShowFilters;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  const _MapControls({
    required this.onRefresh,
    required this.isRefreshing,
    required this.onCenterMap,
    required this.onShowFilters,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 16,
      right: 16,
      child: Column(
        children: [
          _MapControlButton(
              icon: Icons.refresh,
              onPressed: isRefreshing ? null : onRefresh,
              tooltip: 'Refresh Reports'),
          const SizedBox(height: 8),
          _MapControlButton(
              icon: Icons.my_location,
              onPressed: onCenterMap,
              tooltip: 'Center on Location'),
          const SizedBox(height: 8),
          _MapControlButton(
              icon: Icons.filter_list,
              onPressed: onShowFilters,
              tooltip: 'Filters'),
          const SizedBox(height: 24),
          _MapControlButton(
              icon: Icons.add, onPressed: onZoomIn, tooltip: 'Zoom In'),
          const SizedBox(height: 8),
          _MapControlButton(
              icon: Icons.remove, onPressed: onZoomOut, tooltip: 'Zoom Out'),
        ],
      ),
    );
  }
}

class _MapControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;

  const _MapControlButton(
      {required this.icon, this.onPressed, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2))
        ],
      ),
      child: IconButton(
          icon: Icon(icon),
          onPressed: onPressed,
          tooltip: tooltip,
          iconSize: 20),
    );
  }
}

class _ActiveAssignmentHeader extends StatelessWidget {
  final ReportEntity assignment;
  final LatLng currentPosition;

  const _ActiveAssignmentHeader(
      {required this.assignment, required this.currentPosition});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border(bottom: BorderSide(color: Colors.blue.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.blue.shade600,
                    borderRadius: BorderRadius.circular(12)),
                child: const Text('ACTIVE ASSIGNMENT',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
              const Spacer(),
              _SeverityIndicator(severity: assignment.state?.severity ?? 0.5),
            ],
          ),
          const SizedBox(height: 8),
          Text(assignment.title,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(assignment.fullAddress,
              style: TextStyle(color: Colors.grey[700], fontSize: 14)),
          const SizedBox(height: 4),
          Text(
              'Distance: ${calculateDistance(currentPosition, LatLng(assignment.latitude, assignment.longitude)).toStringAsFixed(1)} km',
              style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        ],
      ),
    );
  }
}

class _ActiveAssignmentActions extends StatelessWidget {
  final ReportEntity assignment;
  final bool isRouteLoading;
  final bool hasRoute;
  final VoidCallback onGetDirections;
  final VoidCallback onClearRoute;
  final Function(String) onUpdateStatus;

  const _ActiveAssignmentActions({
    required this.assignment,
    required this.isRouteLoading,
    required this.hasRoute,
    required this.onGetDirections,
    required this.onClearRoute,
    required this.onUpdateStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, -2))
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: hasRoute
                ? OutlinedButton.icon(
                    onPressed: onClearRoute,
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Clear Route'),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue.shade600,
                        side: BorderSide(color: Colors.blue.shade600),
                        padding: const EdgeInsets.symmetric(vertical: 12)),
                  )
                : ElevatedButton.icon(
                    onPressed: isRouteLoading ? null : onGetDirections,
                    icon: isRouteLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.directions),
                    label: const Text('Get Directions'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12)),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => onUpdateStatus('en_route'),
              icon: const Icon(Icons.directions_run),
              label: const Text('On My Way'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12)),
            ),
          ),
        ],
      ),
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
