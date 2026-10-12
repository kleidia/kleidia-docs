# Ports and Services

**Audience**: Operations Administrators  
**Prerequisites**: Network knowledge  
**Outcome**: Understand ports and services used by Kleidia

## External Ports

### HTTP/HTTPS

- **Port 443**: HTTPS (web interface and API via external load balancer)

## Kubernetes Services

### Backend Service

- **Type**: NodePort
- **Port**: 32570 (configurable)
- **Protocol**: HTTP
- **Access**: Via external load balancer (port 443)

### Backend Metrics Service (2.5.0+)

- **Name**: `backend-metrics`
- **Type**: ClusterIP (cluster-internal only)
- **Port**: 9100 (`metrics`, backend `METRICS_PORT`)
- **Protocol**: HTTP, Prometheus text format at `/metrics`, no authentication
- **Access**: Prometheus inside the cluster. Not on the NodePort backend Service, the API ports or the ingress. See [Monitoring and Logs](../04-operations/monitoring-and-logs.md#application-metrics-prometheus)

### Frontend Service

- **Type**: NodePort
- **Port**: 30805 (configurable)
- **Protocol**: HTTP
- **Access**: Via external load balancer (port 443)

### PostgreSQL Service

- **Type**: ClusterIP (internal only)
- **Port**: 5432
- **Protocol**: PostgreSQL
- **Access**: Internal Kubernetes only

### OpenBao (Vault) Service

- **Type**: ClusterIP (internal only)
- **Port**: 8200
- **Protocol**: HTTP
- **Access**: Internal Kubernetes only

## Agent Ports

### Local Agent

- **Port**: 56123 (configurable)
- **Protocol**: HTTP
- **Access**: localhost only (127.0.0.1)
- **⚠️ CRITICAL**: Never exposed externally

## Service Endpoints

### Backend API Endpoints

- `/api/health` - Health check
- `/api/auth/login` - User login
- `/api/auth/logout` - User logout
- `/api/yubikeys` - YubiKey management
- `/api/admin/*` - Admin operations

### Frontend Endpoints

- `/` - Web interface
- `/dashboard` - User dashboard
- `/dashboard/admin` - Admin panel
- `/login` - Login page

### Agent Endpoints

- `/.well-known/kleidia-agent` - Agent discovery
- `/health` - Health check
- `/pubkey` - Public key endpoint
- `/piv/*` - YubiKey operations

## Network Architecture

### External Access

```
Internet
  │
  ▼
External Load Balancer (Port 443)
  │
  ├── Frontend (NodePort 30805)
  └── Backend (NodePort 32570)
```

### Internal Communication

```
Backend
  │
  ├── PostgreSQL (Port 5432, ClusterIP)
  └── OpenBao (Port 8200, ClusterIP)

Prometheus ──▶ Backend metrics (Port 9100, ClusterIP backend-metrics)
```

### Agent Communication

```
Browser (Frontend)
  │
  └── Agent (localhost:56123, HTTP)
```

## Firewall Configuration

### Inbound Rules (Server)

- **Port 443**: Allow (for HTTPS)

### Agent Workstations

- **No Inbound Ports**: Agents use localhost only
- **Outbound HTTPS**: Allow

## Security Considerations

- ✅ Use firewall to restrict access
- ✅ Only expose necessary ports
- ✅ Use internal services for database and Vault
- ✅ Never expose agent ports externally
- ✅ Use HTTPS for all external communication

## Related Documentation

- [Architecture](../01-architecture/system-overview.md)
- [Deployment](../03-deployment/)

