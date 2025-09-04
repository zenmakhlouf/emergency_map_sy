# Report Participation Endpoints - Detailed Documentation

## Overview
The participation system allows responders to request assignment to emergency reports, coordinators to request responders to respond to a report, and for both to accept,reject and cancel. This is a critical workflow for emergency response coordination.

## Endpoint 1: Create/Update Participation Request

### POST `{{url}}/request-participation/{report_id}`

**Purpose**: 
- Responders can request to respond to a specific emergency report
- Coordinators can request assign responders to reports
- Both can accept/reject/cancel existing requests

**URL Parameters**:
- `report_id`: The ID of the emergency report (e.g., 53)

**Request Body**:
```json
{
  "responder_id": 4,
  "status": "cancelled" 
}
```

**Body Fields**:
- `responder_id` (required): ID of the responder being assigned/requesting
- `status` (optional): Can be `"accept"`, `"reject"`, or `"cancelled"`
  - If omitted, creates a new "pending" request
  - Use this to update existing request status
  - if accept it becomes accepted

**Response**:
```json
{
  "message": "request processed successfully",
  "data": {
    "id": 4,
    "initiator": {
      "id": 4,
      "name": "Zen",
      "email": null,
      "last_active_at": "2025-09-03 08:03",
      "last_login_at": "2025-09-03 07:25",
      "roles": [
        {
          "id": 3,
          "name": "citizen",
          "pivot": {
            "model_type": "App\\Models\\User",
            "model_id": 4,
            "role_id": 3
          }
        },
        {
          "id": 4,
          "name": "responder",
          "pivot": {
            "model_type": "App\\Models\\User",
            "model_id": 4,
            "role_id": 4
          }
        }
      ]
    },
    "responder": {
      "id": 4,
      "name": "Zen",
      "email": null,
      "last_active_at": "2025-09-03 08:03",
      "last_login_at": "2025-09-03 07:25",
      "roles": [
        {
          "id": 3,
          "name": "citizen"
        },
        {
          "id": 4,
          "name": "responder"
        }
      ]
    },
    "status": "pending",
    "report": {
      "id": 53,
      "initiator": {
        "id": 5,
        "name": "Sara"
      },
      "latest_status": {
        "id": 53,
        "status": "submitted",
        "status_display": "Submitted",
        "status_color": "blue",
        "notes": "Report submitted",
        "created_at": "2025-09-01T20:40:10.000000Z"
      },
      "created_at": "2025-09-01 23:40",
      "updated_at": "2025-09-01 23:40"
    }
  }
}
```

**Key Response Fields**:
- `id`: Participation request ID
- `initiator`: User who created the participation request
- `responder`: User who will respond to the emergency
- `status`: Current status (`"pending"`, `"accept"`, `"reject"`, `"cancelled"`)
- `report`: Full emergency report details with current status

---

## Endpoint 2: Get All Participation Requests

### GET `{{url}}/request-participation`

**Purpose**: Retrieve all participation requests across the system (likely filtered by user role/permissions)

**Request**: No body required

**Response**:
```json
{
  "message": "success",
  "data": [
    {
      "id": 1,
      "initiator": {
        "id": 4,
        "name": "Zen",
        "email": null,
        "last_active_at": "2025-09-03 13:02",
        "last_login_at": "2025-09-03 07:25",
        "roles": [
          {
            "id": 3,
            "name": "citizen"
          },
          {
            "id": 4,
            "name": "responder"
          }
        ]
      },
      "responder": {
        "id": 4,
        "name": "Zen",
        "email": null,
        "last_active_at": "2025-09-03 13:02",
        "last_login_at": "2025-09-03 07:25",
        "roles": [
          {
            "id": 3,
            "name": "citizen"
          },
          {
            "id": 4,
            "name": "responder"
          }
        ]
      },
      "status": "pending",
      "report": {
        "id": 45,
        "initiator": {
          "id": 9,
          "name": "Zenoo"
        },
        "latest_status": {
          "id": 45,
          "status": "submitted",
          "status_display": "Submitted",
          "status_color": "blue",
          "notes": "Report submitted",
          "created_at": "2025-09-01T00:35:33.000000Z"
        },
        "created_at": "2025-09-01 03:35",
        "updated_at": "2025-09-01 03:35"
      }
    }
    // ... more participation requests
  ]
}
```

**Response Structure**:
- Returns an array of participation request objects
- Each object has the same structure as the POST endpoint response
- Includes full user details for both initiator and responder
- Includes complete report information with current status

---

## Endpoint 3: Get Participation Requests by Report

### GET `{{url}}/request-participation/{report_id}`

**Purpose**: Get all participation requests for a specific emergency report

**URL Parameters**:
- `report_id`: The ID of the emergency report (e.g., 45)

**Request**: No body required

**Response**:
```json
{
  "message": "success",
  "data": [
    {
      "id": 1,
      "initiator": {
        "id": 4,
        "name": "Zen",
        "email": null,
        "last_active_at": "2025-09-03 13:12",
        "last_login_at": "2025-09-03 13:10",
        "roles": [
          {
            "id": 3,
            "name": "citizen"
          },
          {
            "id": 4,
            "name": "responder"
          }
        ]
      },
      "responder": {
        "id": 4,
        "name": "Zen",
        "email": null,
        "last_active_at": "2025-09-03 13:12",
        "last_login_at": "2025-09-03 13:10",
        "roles": [
          {
            "id": 3,
            "name": "citizen"
          },
          {
            "id": 4,
            "name": "responder"
          }
        ]
      },
      "status": "pending",
      "report": {
        "id": 45,
        "initiator": {
          "id": 9,
          "name": "Zenoo"
        },
        "latest_status": {
          "id": 45,
          "status": "submitted",
          "status_display": "Submitted",
          "status_color": "blue",
          "notes": "Report submitted",
          "created_at": "2025-09-01T00:35:33.000000Z"
        },
        "created_at": "2025-09-01 03:35",
        "updated_at": "2025-09-01 03:35"
      }
    }
  ]
}
```

**Response Structure**:
- Returns array of participation requests for the specified report
- Same object structure as other endpoints
- Useful for coordinators to see who has requested to respond to a specific emergency

---

## Implementation Notes for Flutter

### Authentication
All endpoints require Bearer token authentication in the Authorization header.

### Error Handling
Implement proper error handling for:
- Permission denied (user doesn't have coordinator/responder role)
- Network connectivity issues
- Invalid status values

### Status Flow
```
pending → accept/reject/cancelled
```

### User Roles Context
- **Citizens**: Cannot access these endpoints
- **Responders**: Can create participation requests for themselves and cacncel them, can accept or decline participation requests coming from coordinator
- **Coordinators**: Can create requests for any responder and manage all requests
- **AI Agents**: Not involved in participation workflow

### UI Considerations
- Show different interfaces based on user role
- Real-time updates for status changes //by polling the http requests pseudo realtime
- Clear visual indicators for request status
- Confirmation dialogs for accept/reject actions

### Data Models Needed
```dart
class ParticipationRequest {
  int id;
  User initiator;
  User responder;
  String status; // pending, accept, reject, cancelled
  EmergencyReport report;
}

class EmergencyReport {
  int id;
  User initiator;
  ReportStatus latestStatus;
  DateTime createdAt;
  DateTime updatedAt;
}
```