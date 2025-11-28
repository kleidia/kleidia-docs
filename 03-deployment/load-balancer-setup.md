# Load Balancer Setup

**Audience**: Operations Administrators, Network Engineers  
**Prerequisites**: Kleidia deployed with NodePort services, DNS configured  
**Outcome**: Configure external load balancer for HTTPS access

## Overview

Kleidia services are exposed via Kubernetes NodePort services. An external load balancer (HAProxy, Nginx, or cloud load balancer) is required to:

- Terminate SSL/TLS
- Route traffic to appropriate services
- Provide a single entry point (VIP)

## Architecture

```
                    ┌─────────────────┐
                    │   Internet      │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │  Load Balancer  │
                    │  (HAProxy/Nginx)│
                    │  :443 (HTTPS)   │
                    └────────┬────────┘
                             │
           ┌─────────────────┼─────────────────┐
           │                 │                 │
    ┌──────▼──────┐   ┌──────▼──────┐   ┌──────▼──────┐
    │  /api/*     │   │  /*         │   │  (future)   │
    │  Backend    │   │  Frontend   │   │             │
    │  :32570     │   │  :30805     │   │             │
    └─────────────┘   └─────────────┘   └─────────────┘
```

## NodePort Services

After Kleidia installation, the following NodePort services are available:

| Service | NodePort | Internal Port | Description |
|---------|----------|---------------|-------------|
| Backend | 32570 | 8080 | API server |
| Frontend | 30805 | 80 | Web application |

Verify with:
```bash
kubectl get services -n kleidia
```

## Option 1: HAProxy (Recommended)

HAProxy provides high-performance load balancing with SSL termination.

### Installation

```bash
# Ubuntu/Debian
sudo apt update && sudo apt install -y haproxy

# RHEL/CentOS
sudo dnf install -y haproxy

# Verify installation
haproxy -v
```

### SSL Certificate Setup

#### Using Let's Encrypt (Recommended)

```bash
# Install certbot
sudo apt install -y certbot

# Stop any service on port 80 temporarily
sudo systemctl stop haproxy

# Obtain certificate
sudo certbot certonly --standalone -d kleidia.example.com

# Create combined PEM for HAProxy
sudo mkdir -p /etc/haproxy/certs
sudo cat /etc/letsencrypt/live/kleidia.example.com/fullchain.pem \
         /etc/letsencrypt/live/kleidia.example.com/privkey.pem \
         > /etc/haproxy/certs/kleidia.example.com.pem
sudo chmod 600 /etc/haproxy/certs/kleidia.example.com.pem
sudo chown haproxy:haproxy /etc/haproxy/certs/kleidia.example.com.pem
```

#### Auto-Renewal Script

Create `/etc/letsencrypt/renewal-hooks/deploy/haproxy-reload.sh`:

```bash
#!/bin/bash
# Auto-reload HAProxy when Let's Encrypt certificate renews
DOMAIN="kleidia.example.com"

cat /etc/letsencrypt/live/${DOMAIN}/fullchain.pem \
    /etc/letsencrypt/live/${DOMAIN}/privkey.pem \
    > /etc/haproxy/certs/${DOMAIN}.pem

chmod 600 /etc/haproxy/certs/${DOMAIN}.pem
chown haproxy:haproxy /etc/haproxy/certs/${DOMAIN}.pem
systemctl reload haproxy

echo "HAProxy certificate updated and reloaded at $(date)"
```

```bash
sudo chmod +x /etc/letsencrypt/renewal-hooks/deploy/haproxy-reload.sh
```

### HAProxy Configuration

Create `/etc/haproxy/haproxy.cfg`:

```haproxy
global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin
    stats timeout 30s
    user haproxy
    group haproxy
    daemon

    # SSL settings
    ssl-default-bind-ciphersuites TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256
    ssl-default-bind-options ssl-min-ver TLSv1.2 no-tls-tickets

defaults
    log     global
    mode    http
    option  httplog
    option  dontlognull
    option  forwardfor
    timeout connect 5000
    timeout client  50000
    timeout server  50000
    errorfile 400 /etc/haproxy/errors/400.http
    errorfile 403 /etc/haproxy/errors/403.http
    errorfile 408 /etc/haproxy/errors/408.http
    errorfile 500 /etc/haproxy/errors/500.http
    errorfile 502 /etc/haproxy/errors/502.http
    errorfile 503 /etc/haproxy/errors/503.http
    errorfile 504 /etc/haproxy/errors/504.http

# HTTP frontend - redirect to HTTPS and handle ACME challenges
frontend http-in
    bind *:80
    
    # Allow ACME challenges for certificate renewal
    acl is_acme path_beg /.well-known/acme-challenge
    use_backend acme_backend if is_acme
    
    # Redirect all other HTTP to HTTPS
    redirect scheme https code 301 if !is_acme

# ACME challenge backend (for certbot webroot mode)
backend acme_backend
    mode http
    server acme 127.0.0.1:8080

# HTTPS frontend
frontend https-in
    bind *:443 ssl crt /etc/haproxy/certs/kleidia.example.com.pem
    
    # Forward client info
    option forwardfor
    
    # Security headers
    http-response set-header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
    http-response set-header X-Content-Type-Options "nosniff"
    http-response set-header X-Frame-Options "SAMEORIGIN"
    http-response set-header X-XSS-Protection "1; mode=block"
    
    # Route API requests to backend
    acl is_api path_beg -i /api
    use_backend kleidia_backend if is_api
    
    # Everything else goes to frontend
    default_backend kleidia_frontend

# Backend API server
backend kleidia_backend
    balance roundrobin
    option forwardfor
    http-request set-header X-Forwarded-Proto https
    http-request set-header X-Forwarded-Port 443
    http-request set-header X-Real-IP %[src]
    
    # Health check
    option httpchk GET /health
    http-check expect status 200
    
    # Server(s) - add more for HA
    server backend1 127.0.0.1:32570 check

# Frontend web application
backend kleidia_frontend
    balance roundrobin
    option forwardfor
    http-request set-header X-Forwarded-Proto https
    http-request set-header X-Forwarded-Port 443
    http-request set-header X-Real-IP %[src]
    
    # Server(s) - add more for HA
    server frontend1 127.0.0.1:30805 check

# Stats page (optional, disable in production or restrict access)
listen stats
    bind 127.0.0.1:8404
    stats enable
    stats uri /stats
    stats refresh 10s
    stats admin if LOCALHOST
```

### Start HAProxy

```bash
# Validate configuration
sudo haproxy -c -f /etc/haproxy/haproxy.cfg

# Start and enable
sudo systemctl enable haproxy
sudo systemctl start haproxy

# Check status
sudo systemctl status haproxy
```

## Option 2: Nginx

Nginx is a popular alternative with similar capabilities.

### Installation

```bash
# Ubuntu/Debian
sudo apt update && sudo apt install -y nginx

# RHEL/CentOS
sudo dnf install -y nginx
```

### SSL Certificate Setup

```bash
# Using certbot with nginx plugin
sudo apt install -y certbot python3-certbot-nginx

# Obtain and configure certificate
sudo certbot --nginx -d kleidia.example.com
```

### Nginx Configuration

Create `/etc/nginx/sites-available/kleidia`:

```nginx
# Redirect HTTP to HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name kleidia.example.com;
    
    # Allow ACME challenges
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    # Redirect everything else to HTTPS
    location / {
        return 301 https://$server_name$request_uri;
    }
}

# HTTPS server
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name kleidia.example.com;
    
    # SSL configuration
    ssl_certificate /etc/letsencrypt/live/kleidia.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/kleidia.example.com/privkey.pem;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;
    ssl_session_tickets off;
    
    # Modern SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    
    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    
    # Proxy settings
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-Port $server_port;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    
    # API routes -> Backend
    location /api/ {
        proxy_pass http://127.0.0.1:32570;
        proxy_read_timeout 90s;
        proxy_connect_timeout 90s;
        proxy_send_timeout 90s;
    }
    
    # Health check endpoint
    location /health {
        proxy_pass http://127.0.0.1:32570;
    }
    
    # Everything else -> Frontend
    location / {
        proxy_pass http://127.0.0.1:30805;
        proxy_read_timeout 90s;
    }
}
```

### Enable and Start Nginx

```bash
# Enable site
sudo ln -s /etc/nginx/sites-available/kleidia /etc/nginx/sites-enabled/

# Remove default site
sudo rm /etc/nginx/sites-enabled/default

# Test configuration
sudo nginx -t

# Reload nginx
sudo systemctl reload nginx
```

## Option 3: Cloud Load Balancers

### AWS Application Load Balancer (ALB)

```yaml
# Example Kubernetes Ingress for AWS ALB
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: kleidia-ingress
  namespace: kleidia
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:region:account:certificate/xxx
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS":443}]'
    alb.ingress.kubernetes.io/ssl-redirect: '443'
spec:
  rules:
  - host: kleidia.example.com
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: backend
            port:
              number: 8080
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend
            port:
              number: 80
```

### Azure Application Gateway

Configure via Azure Portal or Terraform:
- Frontend IP: Public IP
- Listener: HTTPS on port 443 with SSL certificate
- Backend pools: Kubernetes node IPs
- Backend settings: HTTP to NodePorts (32570, 30805)
- Routing rules: Path-based routing for /api/* and /*

### GCP Cloud Load Balancer

Use GKE Ingress with managed certificates:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: kleidia-ingress
  namespace: kleidia
  annotations:
    kubernetes.io/ingress.class: gce
    kubernetes.io/ingress.global-static-ip-name: kleidia-ip
    networking.gke.io/managed-certificates: kleidia-cert
spec:
  rules:
  - host: kleidia.example.com
    http:
      paths:
      - path: /api/*
        pathType: ImplementationSpecific
        backend:
          service:
            name: backend
            port:
              number: 8080
      - path: /*
        pathType: ImplementationSpecific
        backend:
          service:
            name: frontend
            port:
              number: 80
```

## Verification

### Test HTTPS Access

```bash
# Test SSL certificate
openssl s_client -connect kleidia.example.com:443 -servername kleidia.example.com

# Test API endpoint
curl -I https://kleidia.example.com/api/health

# Test frontend
curl -I https://kleidia.example.com/

# Check HTTP redirect
curl -I http://kleidia.example.com/
```

### Expected Results

```
# API health check
HTTP/2 200
content-type: application/json

# Frontend
HTTP/2 200
content-type: text/html

# HTTP redirect
HTTP/1.1 301 Moved Permanently
location: https://kleidia.example.com/
```

## Troubleshooting

### Connection Refused

```bash
# Check NodePort services are running
kubectl get services -n kleidia

# Test NodePort directly
curl http://localhost:32570/health
curl http://localhost:30805/
```

### SSL Certificate Issues

```bash
# Check certificate expiry
openssl s_client -connect kleidia.example.com:443 2>/dev/null | openssl x509 -noout -dates

# Test certificate renewal
sudo certbot renew --dry-run

# Check HAProxy certificate
sudo openssl x509 -in /etc/haproxy/certs/kleidia.example.com.pem -noout -text
```

### 502 Bad Gateway

```bash
# Check backend health
kubectl logs -f deployment/backend -n kleidia

# Check HAProxy logs
sudo journalctl -u haproxy -f

# Check Nginx logs
sudo tail -f /var/log/nginx/error.log
```

### CORS Errors

Ensure the backend CORS configuration includes your domain:

```bash
# Check CORS_ORIGINS in backend deployment
kubectl get deployment backend -n kleidia -o jsonpath='{.spec.template.spec.containers[0].env}' | jq '.[] | select(.name=="CORS_ORIGINS")'
```

If incorrect, upgrade with the correct domain:

```bash
helm upgrade kleidia-services ./helm/kleidia-services \
  --namespace kleidia \
  --set global.domain=kleidia.example.com
```

## Security Considerations

1. **TLS 1.2+**: Disable older TLS versions
2. **Strong Ciphers**: Use modern cipher suites
3. **HSTS**: Enable HTTP Strict Transport Security
4. **Certificate Renewal**: Automate Let's Encrypt renewal
5. **Rate Limiting**: Consider adding rate limiting for API endpoints
6. **Access Logs**: Enable and monitor access logs

## Related Documentation

- [Helm Installation](helm-install.md)
- [Prerequisites](prerequisites.md)
- [Troubleshooting](troubleshooting.md)

