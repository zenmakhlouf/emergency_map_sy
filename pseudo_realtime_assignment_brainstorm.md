# Pseudo-Realtime Assignment System - Brainstorming

## Current Approach Analysis

### Your Proposed Solution ✅
**Leverage existing polling infrastructure:**
- Already polling `GET /users` and `GET /reports`  
- `GET /users` response includes `participation_requests` array
- Use this data to detect assignment changes

---

## Responder Flow

### Detection Logic
```dart
// In existing users polling loop
for (User user in allUsers) {
  if (user.id == currentUserId) {
    for (ParticipationRequest request in user.participationRequests) {
      // Key insight: If initiator != me, it's an incoming assignment
      if (request.initiator.id != currentUserId && request.status == 'pending') {
        _handleIncomingAssignment(request);
      }
    }
  }
}
```

### State Management
```dart
class AssignmentCubit {
  // Track requests we've already seen to avoid duplicate prompts
  Set<int> _seenRequestIds = {};
  
  void _handleIncomingAssignment(ParticipationRequest request) {
    if (_seenRequestIds.contains(request.id)) return;
    
    _seenRequestIds.add(request.id);
    _showAssignmentPrompt(request);
  }
}
```

---

## Coordinator Flow  

### Assignment Creation
```dart
class CoordinatorAssignmentManager {
  // Track assignments we've sent
  Map<int, PendingAssignment> _sentAssignments = {};
  
  Future<void> assignResponder(int reportId, int responderId) {
    final request = await Network.postData(
      url: '${Urls.baseUrl}/request-participation/$reportId',
      body: {'responder_id': responderId}
    );
    
    // Store locally for tracking
    _sentAssignments[request.data['id']] = PendingAssignment(
      requestId: request.data['id'],
      reportId: reportId,
      responderId: responderId,
      sentAt: DateTime.now(),
    );
  }
}
```

### Status Monitoring
```dart
// In existing users polling loop
void _checkAssignmentStatus(List<User> allUsers) {
  for (final assignment in _sentAssignments.values) {
    final responder = allUsers.firstWhere((u) => u.id == assignment.responderId);
    
    final request = responder.participationRequests
        .firstWhere((r) => r.id == assignment.requestId);
    
    if (request.status != 'pending') {
      _handleAssignmentResponse(assignment, request.status);
    }
  }
}
```

---

## Edge Cases & Solutions

### 1. **Duplicate Assignment Prevention**
```dart
// Before creating assignment, check if responder already assigned
bool _isResponderAvailable(int responderId, int reportId) {
  final existingRequests = _getActiveRequestsForReport(reportId);
  return !existingRequests.any((r) => r.responderId == responderId && r.status == 'accept');
}
```

### 2. **Request Expiration**
```dart
class PendingAssignment {
  DateTime sentAt;
  Duration timeout = Duration(minutes: 15);
  
  bool get isExpired => DateTime.now().difference(sentAt) > timeout;
}

// In polling loop
_sentAssignments.removeWhere((id, assignment) {
  if (assignment.isExpired) {
    _handleExpiredAssignment(assignment);
    return true;
  }
  return false;
});
```

### 3. **Offline Responder Handling**
```dart
// Track last seen timestamp in user data
bool _isResponderOnline(User responder) {
  final lastSeen = DateTime.parse(responder.lastActiveAt);
  return DateTime.now().difference(lastSeen) < Duration(minutes: 5);
}
```

---

## Implementation Strategy

### Phase 1: Basic Polling Integration ⭐
- [x] Use existing `GET /users` polling
- [x] Detect incoming assignments for responders  
- [x] Track sent assignments for coordinators
- [x] Basic accept/reject flow

### Phase 2: Enhanced State Management
- [ ] Deduplication logic
- [ ] Request expiration handling
- [ ] Offline detection
- [ ] Local persistence

### Phase 3: UI/UX Polish
- [ ] Assignment notification UI
- [ ] Focused response mode
- [ ] Assignment dashboard for coordinators
- [ ] Status indicators

---

## Alternative Approaches

### Option A: Enhanced Polling (Current Choice) ⭐
**Pros:**
- Uses existing infrastructure
- No backend changes needed
- Reliable with current API design
- Easy to implement and test

**Cons:**
- Not truly real-time (30s+ delays)
- Higher battery/data usage
- Potential race conditions

### Option B: Hybrid Approach  
- Keep polling for core functionality
- Add local push notifications for critical assignments
- Use WebSocket for active assignments only

**Pros:**
- Better user experience
- More efficient for active cases

**Cons:**
- More complex implementation
- Requires backend changes

### Option C: Pure WebSocket
**Pros:**
- True real-time updates
- Most efficient for active users

**Cons:**
- Requires significant backend work
- Connection reliability issues
- Not feasible with current resources

---

## Recommended Implementation

### **Go with Enhanced Polling (Option A)**

**Why this is the best choice:**
1. **Leverages existing infrastructure** - Already polling users/reports
2. **Zero backend changes** - Works with current API
3. **Reliable** - HTTP is more reliable than WebSocket
4. **Implementable** - I can build this robustly in Flutter
5. **Testable** - Easy to test different scenarios
6. **Scalable enough** - For current user base, polling every 20-30s is acceptable

### Key Implementation Points:
```dart
class AssignmentManager {
  // For responders: detect incoming assignments
  void _processUserUpdates(List<User> users) {
    final myUser = users.firstWhere((u) => u.id == currentUserId);
    _checkForIncomingAssignments(myUser.participationRequests);
  }
  
  // For coordinators: track assignment responses  
  void _trackAssignmentResponses(List<User> users) {
    for (final assignment in _pendingAssignments) {
      final responder = users.firstWhere((u) => u.id == assignment.responderId);
      _checkAssignmentStatus(responder, assignment);
    }
  }
}
```

**This approach will work well because:**
- Existing polling frequency (20s) is acceptable for assignments
- Users endpoint already returns all needed data
- Can implement robust deduplication and error handling
- Easy to add UI feedback and state management
- Can optimize polling frequency for active assignments

---

## Next Steps

1. **Implement basic detection logic** in existing polling loops
2. **Add state management** for tracking requests
3. **Create assignment UI components**
4. **Add focused response mode** for active responders
5. **Build coordinator dashboard** for assignment management

Would you like me to start implementing the core assignment detection logic?