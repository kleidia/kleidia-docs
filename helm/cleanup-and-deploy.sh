#!/bin/bash
# Comprehensive Cleanup and Fresh Deployment Script
# Fixes issues and deploys Kleidia from scratch using DockerHub images

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="kleidia"
DOMAIN="${DOMAIN:-kleidia.example.com}"
HELM_TIMEOUT="30m"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v helm &> /dev/null; then
        log_error "Helm is not installed. Please install Helm 3.8+"
        exit 1
    fi
    
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed. Please install kubectl"
        exit 1
    fi
    
    # Verify kubectl connectivity
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster. Check kubectl configuration."
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Comprehensive cleanup
comprehensive_cleanup() {
    log_info "=== Starting comprehensive cleanup ==="
    
    # Uninstall Helm releases in reverse order
    log_info "Uninstalling Helm releases..."
    
    for release in kleidia-services kleidia-data kleidia-platform; do
        if helm list -n "$NAMESPACE" 2>/dev/null | grep -q "$release"; then
            log_info "Uninstalling $release..."
            helm uninstall "$release" -n "$NAMESPACE" --wait --timeout=5m || true
            sleep 5
        fi
    done
    
    if kubectl get namespace "$NAMESPACE" &>/dev/null; then
        log_info "Cleaning up namespace resources..."
        
        # Force delete all resources
        kubectl delete jobs --all -n "$NAMESPACE" --force --grace-period=0 2>/dev/null || true
        kubectl delete pods --all -n "$NAMESPACE" --force --grace-period=0 2>/dev/null || true
        kubectl delete deployment --all -n "$NAMESPACE" --force --grace-period=0 2>/dev/null || true
        kubectl delete statefulset --all -n "$NAMESPACE" --force --grace-period=0 2>/dev/null || true
        kubectl delete svc --all -n "$NAMESPACE" --force --grace-period=0 2>/dev/null || true
        kubectl delete configmap --all -n "$NAMESPACE" --force --grace-period=0 2>/dev/null || true
        kubectl delete secret --all -n "$NAMESPACE" --force --grace-period=0 2>/dev/null || true
        
        # Delete PVCs (this will also trigger PV deletion)
        log_info "Deleting PersistentVolumeClaims..."
        kubectl delete pvc --all -n "$NAMESPACE" --wait=false 2>/dev/null || true
        
        # Wait for resources to terminate
        log_info "Waiting for resources to terminate..."
        sleep 20
        
        # Force delete namespace
        log_info "Deleting namespace..."
        kubectl delete namespace "$NAMESPACE" --timeout=120s 2>/dev/null || {
            # If namespace is stuck, force remove finalizers
            log_warning "Namespace stuck, removing finalizers..."
            kubectl get namespace "$NAMESPACE" -o json | \
                jq '.spec.finalizers = []' | \
                kubectl replace --raw "/api/v1/namespaces/$NAMESPACE/finalize" -f - 2>/dev/null || true
        }
        
        # Wait for namespace to be fully deleted
        log_info "Waiting for namespace deletion to complete..."
        for i in {1..30}; do
            if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
                break
            fi
            sleep 2
        done
    fi
    
    # Clean up any orphaned PVs
    log_info "Cleaning up orphaned PersistentVolumes..."
    kubectl get pv | grep "$NAMESPACE" | awk '{print $1}' | xargs -r kubectl delete pv 2>/dev/null || true
    
    log_success "Cleanup completed"
}

# Detect and configure storage class
detect_storage_class() {
    log_info "Detecting available storage classes..."
    
    if kubectl get storageclass nfs-client &>/dev/null; then
        STORAGE_CLASS="nfs-client"
        ENABLE_LOCAL_PATH="false"
        log_success "Found NFS storage class: nfs-client"
    elif kubectl get storageclass local-path &>/dev/null; then
        STORAGE_CLASS="local-path"
        ENABLE_LOCAL_PATH="false"
        log_success "Found local-path storage class: local-path"
    else
        STORAGE_CLASS="local-path"
        ENABLE_LOCAL_PATH="true"
        log_warning "No storage class found. Will enable local-path-provisioner."
    fi
    
    log_info "Using storage class: $STORAGE_CLASS"
}

# Fresh deployment
fresh_deployment() {
    log_info "=== Starting fresh deployment ==="
    
    detect_storage_class
    
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    cd "$SCRIPT_DIR" || exit 1
    
    # Step 1: Install Platform (OpenBao, Storage)
    log_info "Step 1/3: Installing kleidia-platform..."
    helm install kleidia-platform ./kleidia-platform \
        --namespace "$NAMESPACE" \
        --create-namespace \
        --set global.domain="$DOMAIN" \
        --set global.namespace="$NAMESPACE" \
        --set global.registry.host="" \
        --set storage.className="$STORAGE_CLASS" \
        --set storage.localPath.enabled="$ENABLE_LOCAL_PATH" \
        --set openbao.server.dataStorage.storageClass="$STORAGE_CLASS" \
        --set openbao.server.auditStorage.storageClass="$STORAGE_CLASS" \
        --timeout "$HELM_TIMEOUT" \
        --wait
    
    log_success "Platform installed"
    
    # Wait for OpenBao to initialize
    log_info "Waiting for OpenBao to be ready..."
    sleep 30
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=openbao -n "$NAMESPACE" --timeout=600s || {
        log_warning "OpenBao initialization may still be in progress..."
    }
    
    # Step 2: Install Data Layer (PostgreSQL)
    log_info "Step 2/3: Installing kleidia-data..."
    helm install kleidia-data ./kleidia-data \
        --namespace "$NAMESPACE" \
        --set global.domain="$DOMAIN" \
        --set global.namespace="$NAMESPACE" \
        --set global.registry.host="" \
        --set storage.className="$STORAGE_CLASS" \
        --timeout "$HELM_TIMEOUT" \
        --wait
    
    log_success "Data layer installed"
    
    # Wait for PostgreSQL to be ready
    log_info "Waiting for PostgreSQL to be ready..."
    sleep 20
    kubectl wait --for=condition=ready pod -l app=postgres -n "$NAMESPACE" --timeout=300s || {
        log_warning "PostgreSQL may need more time..."
    }
    
    # Step 3: Install Services (Backend, Frontend, License Service)
    log_info "Step 3/3: Installing kleidia-services..."
    helm install kleidia-services ./kleidia-services \
        --namespace "$NAMESPACE" \
        --set global.domain="$DOMAIN" \
        --set global.namespace="$NAMESPACE" \
        --set global.registry.host="" \
        --set backend.corsOrigins="https://$DOMAIN" \
        --set backend.image.repository="therinn/kleidia" \
        --set backend.image.tag="backend-latest" \
        --set frontend.image.repository="therinn/kleidia" \
        --set frontend.image.tag="frontend-latest" \
        --set licenseService.image="therinn/kleidia:license-latest" \
        --timeout "$HELM_TIMEOUT" \
        --wait
    
    log_success "Services installed"
}

# Comprehensive verification
verify_deployment() {
    log_info "=== Verifying deployment ==="
    
    sleep 15
    
    # Check all pods
    log_info "Pod status:"
    kubectl get pods -n "$NAMESPACE" -o wide
    
    echo ""
    log_info "Services:"
    kubectl get svc -n "$NAMESPACE"
    
    echo ""
    log_info "PersistentVolumeClaims:"
    kubectl get pvc -n "$NAMESPACE"
    
    echo ""
    
    # Check for failed pods
    FAILED_PODS=$(kubectl get pods -n "$NAMESPACE" --field-selector=status.phase!=Running,status.phase!=Succeeded --no-headers 2>/dev/null | wc -l)
    
    if [ "$FAILED_PODS" -gt 0 ]; then
        log_warning "Found $FAILED_PODS pod(s) not in Running state:"
        kubectl get pods -n "$NAMESPACE" | grep -v Running | grep -v Succeeded || true
        
        log_info "Checking pod logs for errors..."
        for pod in $(kubectl get pods -n "$NAMESPACE" --field-selector=status.phase!=Running,status.phase!=Succeeded -o name 2>/dev/null); do
            log_info "Logs for $pod:"
            kubectl logs "$pod" -n "$NAMESPACE" --tail=20 2>&1 || true
            echo "---"
        done
    else
        log_success "All pods are running successfully"
    fi
    
    # Test backend health
    log_info "Testing backend health endpoint..."
    BACKEND_POD=$(kubectl get pods -n "$NAMESPACE" -l app=backend -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [ -n "$BACKEND_POD" ]; then
        if kubectl exec -n "$NAMESPACE" "$BACKEND_POD" -- wget -q -O- http://localhost:8080/health 2>/dev/null; then
            log_success "Backend health check passed"
        else
            log_error "Backend health check failed"
            log_info "Backend logs:"
            kubectl logs -n "$NAMESPACE" "$BACKEND_POD" --tail=50
        fi
    else
        log_warning "Backend pod not found for health check"
    fi
}

# Show final status
show_final_status() {
    log_info "=== Deployment Complete ==="
    
    echo ""
    log_info "Helm releases:"
    helm list -n "$NAMESPACE"
    
    echo ""
    log_info "NodePort services for external load balancer:"
    kubectl get svc -n "$NAMESPACE" -o wide | grep NodePort || true
    
    echo ""
    log_success "Application should be available at: https://$DOMAIN"
    log_info "Backend NodePort: 32570"
    log_info "Frontend NodePort: 30805"
    
    echo ""
    log_info "Useful commands:"
    echo "  # View backend logs:"
    echo "  kubectl logs -f deployment/backend -n $NAMESPACE"
    echo ""
    echo "  # View frontend logs:"
    echo "  kubectl logs -f deployment/frontend -n $NAMESPACE"
    echo ""
    echo "  # View all pods:"
    echo "  kubectl get pods -n $NAMESPACE"
    echo ""
    echo "  # Access backend shell:"
    echo "  kubectl exec -it deployment/backend -n $NAMESPACE -- /bin/sh"
}

# Main execution
main() {
    log_info "╔════════════════════════════════════════════════════════╗"
    log_info "║   Kleidia Cleanup and Fresh Deployment                ║"
    log_info "║   Domain: $DOMAIN"
    log_info "║   Namespace: $NAMESPACE"
    log_info "╚════════════════════════════════════════════════════════╝"
    echo ""
    
    check_prerequisites
    comprehensive_cleanup
    fresh_deployment
    verify_deployment
    show_final_status
    
    log_success "=== Deployment completed successfully! ==="
}

# Run main function
main "$@"



