# Assignments Backend Filtering Implementation

## Overview
Updated the assignments feature to properly reflect that the backend handles filtering of participation requests based on the user's bearer token and role.

## Key Changes Made

### 1. AssignmentService Updates
**File**: `lib/features/assignments/repository/assignment_service.dart`

- Updated `getAllParticipationRequests()` documentation to clarify backend filtering:
  - **Coordinators**: Get all requests in the system
  - **Responders**: Get only requests where they are the responder  
  - **Citizens**: Get only requests they initiated

- Updated `getParticipationRequestsForReport()` documentation to clarify role-based filtering for specific reports

### 2. AssignmentsCubit Simplification  
**File**: `lib/features/assignments/cubit/assignments_cubit.dart`

**Removed**:
- `currentUserId` parameter from constructor
- Client-side filtering logic that separated incoming/outgoing requests
- `setCurrentUserId()` method
- User ID null checks

**Simplified**:
- Constructor now automatically starts polling since auth is handled at network level
- `loadAllAssignments()` no longer filters data - uses backend-filtered results directly
- `_silentRefresh()` simplified to work with single data source
- `_hasDataChanged()` now compares single list instead of multiple lists

### 3. State Model Updates
**File**: `lib/features/assignments/cubit/assignments_state.dart`

**Updated `AssignmentsLoaded` state**:
- Added comprehensive documentation explaining backend filtering behavior
- Updated helper getters to work with backend-filtered data:
  - `pendingRequests`, `acceptedRequests`, `rejectedRequests`, `cancelledRequests` 
  - `totalPendingRequests`, `totalAcceptedRequests`
  - `hasPendingRequests`, `hasAcceptedRequests`, `hasAnyRequests`

**Note**: `incomingRequests` and `outgoingRequests` fields maintained for backward compatibility but now contain the same backend-filtered data as `allRequests`.

### 4. Test Updates
**Files**: `test/features/assignments/repository/assignment_service_test.dart`, `test/features/assignments/integration_test.dart`

- Updated test descriptions to reflect "backend-filtered" behavior
- Added documentation about automatic role-based filtering
- All tests continue to pass with new architecture

## Backend Filtering Behavior

### For Coordinators 🎯
```
GET /request-participation
→ Returns: All participation requests in the system
→ Use case: Managing all emergency response assignments
```

### For Responders 🚑  
```
GET /request-participation  
→ Returns: Only requests where current user is the responder
→ Use case: Seeing incoming assignment requests and accepted assignments
```

### For Citizens 👥
```
GET /request-participation
→ Returns: Only requests where current user is the initiator  
→ Use case: Tracking requests they made for emergency response
```

### For Specific Reports 📋
```
GET /request-participation/{reportId}
→ Returns: Requests for the report, filtered by user role
→ Coordinators: All requests for the report
→ Responders: Only their requests for the report  
→ Citizens: Only requests for reports they initiated
```

## Benefits of This Approach

### ✅ **Simplified Client Logic**
- No complex client-side filtering based on user IDs
- Single source of truth from backend
- Reduced client-side state complexity

### ✅ **Better Security** 
- Server-side authorization ensures users only see appropriate data
- No risk of client-side filtering bugs exposing unauthorized data
- Bearer token handles all access control

### ✅ **Performance**
- Reduced data transfer (only relevant requests sent)
- Less client-side processing
- Faster UI updates

### ✅ **Maintainability**
- Business logic centralized on backend
- Easier to modify role-based access rules
- Consistent behavior across different clients

## Migration Notes

### For UI Components
- Use `AssignmentsLoaded.allRequests` for main data source
- Use helper getters like `pendingRequests`, `acceptedRequests` for filtering by status
- Role-based UI logic can rely on data already being filtered appropriately

### For New Features
- When adding new role-based assignment features, rely on backend filtering
- No need to implement client-side user ID checks
- Focus on status-based filtering and UI presentation

## Example Usage

```dart
// In your UI widget
BlocBuilder<AssignmentsCubit, AssignmentsState>(
  builder: (context, state) {
    if (state is AssignmentsLoaded) {
      // Data is already filtered by backend based on user role
      final allRelevantRequests = state.allRequests;
      final pendingRequests = state.pendingRequests; // Status filtering
      final acceptedRequests = state.acceptedRequests; // Status filtering
      
      return ListView.builder(
        itemCount: pendingRequests.length,
        itemBuilder: (context, index) {
          final request = pendingRequests[index];
          // Show request UI - role filtering already done by backend
          return AssignmentRequestCard(request: request);
        },
      );
    }
    return CircularProgressIndicator();
  },
);
```

This implementation ensures clean separation of concerns while maintaining robust security and performance.