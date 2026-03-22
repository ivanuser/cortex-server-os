# Management Server API Reference

The Cortex Management Server exposes a REST API for fleet management operations. All endpoints (except auth) require a valid JWT token.

---

## Base URL

```
http://your-management-server:9443/api
```

## Authentication

### Login

```http
POST /api/auth/login
Content-Type: application/json

{
  "username": "admin",
  "password": "your-password"
}
```

**Response:**

```json
{
  "token": "eyJhbGciOiJIUzI1NiIs...",
  "user": {
    "id": "uuid",
    "username": "admin",
    "role": "admin"
  }
}
```

### Using the Token

Include the JWT in the `Authorization` header:

```http
Authorization: Bearer eyJhbGciOiJIUzI1NiIs...
```

---

## Fleet Endpoints

### List Nodes

```http
GET /api/fleet/nodes
```

**Response:**

```json
{
  "nodes": [
    {
      "id": "uuid",
      "hostname": "web-server-01",
      "gatewayUrl": "http://192.168.1.10:18789",
      "status": "healthy",
      "lastSeen": "2026-03-22T02:00:00Z",
      "metrics": {
        "cpu": 23.5,
        "memory": 67.2,
        "disk": 45.0,
        "uptime": 864000
      },
      "enrolledAt": "2026-03-20T10:00:00Z"
    }
  ]
}
```

### Get Node

```http
GET /api/fleet/nodes/:id
```

### Enroll Node

```http
POST /api/fleet/enroll
Content-Type: application/json

{
  "token": "enrollment-token",
  "hostname": "new-server",
  "gatewayUrl": "http://192.168.1.20:18789",
  "gatewayToken": "node-access-token"
}
```

**Response:**

```json
{
  "id": "uuid",
  "hostname": "new-server",
  "status": "enrolled",
  "enrolledAt": "2026-03-22T02:30:00Z"
}
```

### Remove Node

```http
DELETE /api/fleet/nodes/:id
```

### Update Node

```http
PATCH /api/fleet/nodes/:id
Content-Type: application/json

{
  "hostname": "renamed-server",
  "tags": ["production", "web"]
}
```

---

## Health Endpoints

### Fleet Health Summary

```http
GET /api/fleet/health
```

**Response:**

```json
{
  "total": 5,
  "healthy": 4,
  "degraded": 1,
  "critical": 0,
  "offline": 0,
  "lastPoll": "2026-03-22T02:35:00Z"
}
```

### Node Health Detail

```http
GET /api/fleet/nodes/:id/health
```

**Response:**

```json
{
  "status": "healthy",
  "checks": {
    "gateway": "ok",
    "cpu": { "value": 23.5, "status": "ok" },
    "memory": { "value": 67.2, "status": "ok" },
    "disk": { "value": 45.0, "status": "ok" }
  },
  "lastCheck": "2026-03-22T02:35:00Z"
}
```

### Node Health History

```http
GET /api/fleet/nodes/:id/health/history?hours=24
```

---

## Command Execution

### Send Command to Node

```http
POST /api/fleet/nodes/:id/command
Content-Type: application/json

{
  "message": "Show me disk usage"
}
```

**Response:**

```json
{
  "id": "command-uuid",
  "status": "completed",
  "response": "Here's the current disk usage:\n\n..."
}
```

### Send Command to Multiple Nodes

```http
POST /api/fleet/broadcast
Content-Type: application/json

{
  "nodeIds": ["uuid1", "uuid2"],
  "message": "Run a security audit"
}
```

---

## Incidents

### List Incidents

```http
GET /api/fleet/incidents?status=open&limit=50
```

**Query Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `status` | string | — | Filter: `open`, `acknowledged`, `resolved` |
| `nodeId` | string | — | Filter by node |
| `limit` | number | 50 | Max results |
| `offset` | number | 0 | Pagination offset |

**Response:**

```json
{
  "incidents": [
    {
      "id": "uuid",
      "nodeId": "node-uuid",
      "hostname": "web-server-01",
      "type": "node_offline",
      "severity": "critical",
      "status": "open",
      "message": "Node unreachable for 5 minutes",
      "createdAt": "2026-03-22T02:20:00Z",
      "acknowledgedAt": null,
      "resolvedAt": null
    }
  ],
  "total": 1
}
```

### Acknowledge Incident

```http
POST /api/fleet/incidents/:id/acknowledge
```

### Resolve Incident

```http
POST /api/fleet/incidents/:id/resolve
Content-Type: application/json

{
  "resolution": "Node was rebooted and is now healthy"
}
```

---

## Scheduled Tasks

### List Schedules

```http
GET /api/fleet/schedules
```

### Create Schedule

```http
POST /api/fleet/schedules
Content-Type: application/json

{
  "name": "Weekly Security Audit",
  "schedule": "0 2 * * 1",
  "nodes": ["all"],
  "command": "Run a full security audit",
  "enabled": true
}
```

### Update Schedule

```http
PATCH /api/fleet/schedules/:id
Content-Type: application/json

{
  "enabled": false
}
```

### Delete Schedule

```http
DELETE /api/fleet/schedules/:id
```

---

## Users (Admin Only)

### List Users

```http
GET /api/auth/users
```

### Create User

```http
POST /api/auth/users
Content-Type: application/json

{
  "username": "operator1",
  "password": "secure-password",
  "role": "operator"
}
```

### Roles

| Role | Permissions |
|------|------------|
| `admin` | Full access — manage users, nodes, settings |
| `operator` | Manage nodes, execute commands, view incidents |
| `viewer` | Read-only access to dashboards and status |

---

## System

### API Health

```http
GET /api/health
```

**Response:**

```json
{
  "status": "ok",
  "version": "0.5.1",
  "uptime": 86400,
  "nodes": 5
}
```

### Audit Log

```http
GET /api/system/audit?limit=100
```

---

## Error Responses

All errors follow this format:

```json
{
  "error": "Unauthorized",
  "message": "Invalid or expired token",
  "status": 401
}
```

### Status Codes

| Code | Meaning |
|------|---------|
| 200 | Success |
| 201 | Created |
| 400 | Bad request (invalid input) |
| 401 | Unauthorized (missing/invalid token) |
| 403 | Forbidden (insufficient role) |
| 404 | Not found |
| 429 | Rate limited |
| 500 | Internal server error |

---

## WebSocket

The management server also provides a WebSocket endpoint for real-time updates:

```javascript
const ws = new WebSocket('ws://management-server:9443/ws');

ws.onopen = () => {
  ws.send(JSON.stringify({
    type: 'auth',
    token: 'your-jwt-token'
  }));
};

ws.onmessage = (event) => {
  const data = JSON.parse(event.data);
  // data.type: 'health_update', 'incident', 'command_result', etc.
};
```

### Event Types

| Type | Description |
|------|-------------|
| `health_update` | Node health status changed |
| `incident` | New incident detected |
| `incident_resolved` | Incident resolved |
| `node_enrolled` | New node registered |
| `node_removed` | Node removed from fleet |
| `command_result` | Command execution completed |
