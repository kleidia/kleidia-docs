# CORS Configuration Guide

## Overview

The backend requires CORS (Cross-Origin Resource Sharing) to be configured with the domains that will access it. This is critical for:
- Bootstrap/admin creation flow
- Frontend-to-backend API calls
- Security (prevents unauthorized domains from accessing the API)

## Configuration

### Via Helm Values

Set `backend.corsOrigins` in your `values.yaml` or via `--set`:

```yaml
backend:
  corsOrigins: "https://kleidia.example.com,https://kleidia.smit.dev"
```

Or via command line:

```bash
helm install kleidia-services ./kleidia-services \
  --set backend.corsOrigins="https://kleidia.example.com,https://kleidia.smit.dev"
```

### External Load Balancer Scenarios

#### Scenario 1: Known DNS Before Deployment
If you know your DNS/domain before deployment:

```bash
helm install kleidia-services ./kleidia-services \
  --set backend.corsOrigins="https://my-kleidia.example.com"
```

#### Scenario 2: External LB with Unknown DNS
If using an external load balancer where DNS isn't known until after deployment:

1. **Initial deployment** with localhost (bootstrap will fail):
   ```bash
   helm install kleidia-services ./kleidia-services
   ```

2. **Get your Load Balancer URL/IP** (from cloud provider/VIP)

3. **Upgrade with actual domain**:
   ```bash
   helm upgrade kleidia-services ./kleidia-services \
     --set backend.corsOrigins="https://your-actual-domain.com"
   ```

4. **Restart backend pods** to pick up new configuration:
   ```bash
   kubectl rollout restart deployment/backend -n kleidia
   ```

#### Scenario 3: Multiple Environments
For development + production:

```yaml
backend:
  corsOrigins: "https://kleidia.prod.example.com,https://kleidia.dev.example.com,http://localhost:3000"
```

### VIP/HAProxy Scenario

For this deployment using VIP with HAProxy:

```bash
helm upgrade kleidia-services ./kleidia-services \
  --set backend.corsOrigins="https://kleidia.smit.dev" \
  -n kleidia
```

## Security Considerations

### ⚠️ DO NOT Use Wildcards in Production

```yaml
# ❌ NEVER DO THIS IN PRODUCTION
backend:
  corsOrigins: "*"
```

The backend will reject wildcard (*) origins in production mode.

### ✅ Best Practices

1. **Explicit domains only**: List each allowed domain explicitly
2. **HTTPS in production**: Use `https://` not `http://` for production domains
3. **Include all variations**: If accessible via multiple domains/IPs, include all
4. **Separate by commas**: No spaces in the comma-separated list

### Examples

**Good:**
```yaml
backend:
  corsOrigins: "https://kleidia.example.com,https://kleidia-backup.example.com"
```

**Bad:**
```yaml
backend:
  corsOrigins: "*"  # ❌ Security risk
  corsOrigins: "https://kleidia.example.com, https://other.com"  # ❌ Spaces cause issues
```

## Troubleshooting

### Error: 403 Forbidden on Bootstrap
**Symptom:** Can't create admin, getting 403 errors

**Cause:** Frontend domain not in `corsOrigins`

**Solution:**
```bash
# Check current CORS config
kubectl exec -n kleidia deployment/backend -- printenv CORS_ORIGINS

# Update with correct domain
helm upgrade kleidia-services ./kleidia-services \
  --set backend.corsOrigins="https://your-actual-domain.com" \
  -n kleidia

# Restart backend
kubectl rollout restart deployment/backend -n kleidia
```

### Error: CORS blocks localhost
**Symptom:** Local development failing

**Solution:** Add localhost to the list:
```yaml
backend:
  corsOrigins: "https://kleidia.example.com,http://localhost:3000,http://localhost:5173"
```

## Technical Details

### Backend Behavior

The backend (`main.go`) validates CORS origins:
- Reads from `CORS_ORIGINS` environment variable
- Splits on comma
- Applies to Gin CORS middleware
- Bootstrap endpoints (`/claim`, `/complete`) explicitly check origin headers
- Rejects requests from unlisted origins with 403 Forbidden

### Bootstrap Flow

The admin creation flow requires correct CORS:

1. Frontend loads at `https://kleidia.example.com`
2. User navigates to `/adminSetup`
3. Frontend calls `POST /api/bootstrap/claim` with `Origin: https://kleidia.example.com`
4. Backend checks if origin is in `CORS_ORIGINS`
5. If not found → **403 Forbidden**
6. If found → Returns claim token
7. User submits admin credentials
8. Frontend calls `POST /api/bootstrap/complete` (also checks origin)

## Deployment Examples

### Air-Gapped Deployment
```yaml
backend:
  corsOrigins: "https://kleidia.internal.company.com"
```

### Cloud Deployment with External LB
```bash
# After LB is created and DNS is set up
helm upgrade kleidia-services ./kleidia-services \
  --set backend.corsOrigins="https://$(kubectl get vip kleidia-vip -n kleidia -o jsonpath='{.spec.fqdn}')" \
  -n kleidia
```

### Development + Staging + Production
```yaml
backend:
  corsOrigins: "https://kleidia.prod.example.com,https://kleidia-staging.example.com,http://localhost:3000"
```

## References

- Backend CORS implementation: `backend-go/main.go`
- Bootstrap handlers: `backend-go/internal/handlers/handlers.go` (BootstrapClaim, BootstrapComplete)
- Helm values: `helm/kleidia-services/values.yaml`

