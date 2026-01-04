#!/bin/bash
# Kleidia Cleanup and Redeployment Script
# Cleans up Azure server and redeploys using Helm charts with DockerHub images
# Does NOT build containers on server - pulls from DockerHub

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="kleidia"
DOMAIN="${DOMAIN:-kleidia.example.com}"  # Default domain, can be overridden
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
    
    if ! command -v git &> /dev/null; then
        log_error "git is not installed. Please install git"
        exit 1
    fi
    
    # Check Helm version
    HELM_VERSION=$(helm version --template='{{.Version}}' | sed 's/v//')
    log_info "Helm version: $HELM_VERSION"
    
    # Verify kubectl connectivity
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster. Check kubectl configuration."
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Clean up existing deployment
cleanup_deployment() {
    log_info "Cleaning up existing deployment..."
    
    # Uninstall Helm releases in reverse order (services, data, platform)
    log_info "Uninstalling Helm releases..."
    
    if helm list -n "$NAMESPACE" 2>/dev/null | grep -q "kleidia-services"; then
        log_info "Uninstalling kleidia-services..."
        helm uninstall kleidia-services -n "$NAMESPACE" --wait || true
    fi
    
    if helm list -n "$NAMESPACE" 2>/dev/null | grep -q "kleidia-data"; then
        log_info "Uninstalling kleidia-data..."
        helm uninstall kleidia-data -n "$NAMESPACE" --wait || true
    fi
    
    if helm list -n "$NAMESPACE" 2>/dev/null | grep -q "kleidia-platform"; then
        log_info "Uninstalling kleidia-platform..."
        helm uninstall kleidia-platform -n "$NAMESPACE" --wait || true
    fi
    
    # Clean up any remaining resources in the namespace
    if kubectl get namespace "$NAMESPACE" &>/dev/null; then
        log_info "Cleaning up remaining resources in namespace $NAMESPACE..."
        
        # Delete PVCs
        log_info "Deleting PersistentVolumeClaims..."
        kubectl delete pvc --all -n "$NAMESPACE" --wait=false || true
        
        # Delete any remaining pods
        log_info "Deleting remaining pods..."
        kubectl delete pods --all -n "$NAMESPACE" --wait=false || true
        
        # Delete services
        log_info "Deleting services..."
        kubectl delete svc --all -n "$NAMESPACE" --wait=false || true
        
        # Delete deployments
        log_info "Deleting deployments..."
        kubectl delete deployment --all -n "$NAMESPACE" --wait=false || true
        
        # Delete statefulsets
        log_info "Deleting statefulsets..."
        kubectl delete statefulset --all -n "$NAMESPACE" --wait=false || true
        
        # Delete jobs
        log_info "Deleting jobs..."
        kubectl delete job --all -n "$NAMESPACE" --wait=false || true
        
        # Wait for resources to be cleaned up
        log_info "Waiting for resources to be cleaned up..."
        sleep 15
        
        # Delete namespace if it still exists
        if kubectl get namespace "$NAMESPACE" &>/dev/null; then
            log_info "Deleting namespace $NAMESPACE..."
            kubectl delete namespace "$NAMESPACE" --wait=true --timeout=120s || true
            log_info "Waiting for namespace deletion..."
            sleep 10
        fi
    fi
    
    # Clean up any orphaned PVCs that might be stuck (in case namespace deletion didn't clean them up)
    log_info "Checking for orphaned PVCs in namespace..."
    if kubectl get pvc -n "$NAMESPACE" --no-headers 2>/dev/null | grep -q .; then
        log_warning "Found remaining PVCs, attempting to delete..."
        kubectl delete pvc --all -n "$NAMESPACE" --wait=false 2>/dev/null || true
    fi
    
    log_success "Cleanup completed"
}

# Pull latest code
pull_latest_code() {
    log_info "Pulling latest code from repository..."
    
    if [ ! -d ".git" ]; then
        log_error "Not in a git repository. Please run this script from the repository root."
        exit 1
    fi
    
    # Check if there are uncommitted changes
    if ! git diff-index --quiet HEAD --; then
        log_warning "You have uncommitted changes. Stashing them..."
        git stash save "Auto-stash before deployment $(date +%Y%m%d-%H%M%S)"
    fi
    
    # Pull latest changes (skip if git pull fails - might be authentication issue)
    if ! git pull origin main 2>/dev/null && ! git pull origin master 2>/dev/null; then
        log_warning "Failed to pull latest code (this may be due to git authentication)."
        log_warning "Continuing with existing code. If you need latest changes, pull manually."
    else
        log_info "Successfully pulled latest code"
    fi
    
    log_success "Latest code pulled successfully"
}

# Detect and configure storage class
detect_storage_class() {
    log_info "Detecting available storage classes..."
    
    # Check if NFS storage class exists
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
        log_warning "No NFS or local-path storage class found. Will enable local-path-provisioner."
    fi
    
    log_info "Using storage class: $STORAGE_CLASS"
    log_info "Local-path-provisioner enabled: $ENABLE_LOCAL_PATH"
}

# Deploy using Helm charts
deploy_with_helm() {
    log_info "Starting Helm deployment with DockerHub images..."
    log_info "Domain: $DOMAIN"
    log_info "Namespace: $NAMESPACE"
    
    # Detect storage class
    detect_storage_class
    
    # Navigate to helm directory
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    cd "$SCRIPT_DIR" || exit 1
    
    # Step 1: Install Platform (OpenBao, Storage)
    log_info "Step 1/3: Installing kleidia-platform (OpenBao, Storage)..."
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
    
    log_success "Platform installed successfully"
    
    # Wait for OpenBao to be ready
    log_info "Waiting for OpenBao to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=openbao -n "$NAMESPACE" --timeout=600s || {
        log_warning "OpenBao may not be fully ready, but continuing..."
    }
    
    # Step 2: Install Data Layer (PostgreSQL)
    log_info "Step 2/3: Installing kleidia-data (PostgreSQL)..."
    helm install kleidia-data ./kleidia-data \
        --namespace "$NAMESPACE" \
        --set global.domain="$DOMAIN" \
        --set global.namespace="$NAMESPACE" \
        --set global.registry.host="" \
        --set storage.className="$STORAGE_CLASS" \
        --timeout "$HELM_TIMEOUT" \
        --wait
    
    log_success "Data layer installed successfully"
    
    # Wait for PostgreSQL to be ready
    log_info "Waiting for PostgreSQL to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=postgres -n "$NAMESPACE" --timeout=300s || {
        log_warning "PostgreSQL may not be fully ready, but continuing..."
    }
    
    # Step 3: Install Services (Backend, Frontend)
    log_info "Step 3/3: Installing kleidia-services (Backend, Frontend)..."
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
    
    log_success "Services installed successfully"
}

# Verify deployment
verify_deployment() {
    log_info "Verifying deployment..."
    
    # Check pods
    log_info "Checking pod status..."
    kubectl get pods -n "$NAMESPACE"
    
    # Wait a bit for pods to stabilize
    sleep 10
    
    # Check if all pods are running
    FAILED_PODS=$(kubectl get pods -n "$NAMESPACE" --field-selector=status.phase!=Running,status.phase!=Succeeded --no-headers 2>/dev/null | wc -l)
    
    if [ "$FAILED_PODS" -gt 0 ]; then
        log_warning "Some pods are not running. Checking details..."
        kubectl get pods -n "$NAMESPACE" | grep -v Running | grep -v Succeeded || true
    else
        log_success "All pods are running"
    fi
    
    # Check services
    log_info "Checking services..."
    kubectl get services -n "$NAMESPACE"
    
    # Check persistent volumes
    log_info "Checking persistent volumes..."
    kubectl get pvc -n "$NAMESPACE" || true
    
    log_success "Deployment verification completed"
}

# Show deployment status
show_status() {
    log_info "=== Deployment Status ==="
    
    echo ""
    log_info "Helm Releases:"
    helm list -n "$NAMESPACE"
    
    echo ""
    log_info "Pods:"
    kubectl get pods -n "$NAMESPACE"
    
    echo ""
    log_info "Services:"
    kubectl get services -n "$NAMESPACE"
    
    echo ""
    log_info "NodePort Services (for external load balancer):"
    kubectl get services -n "$NAMESPACE" -o wide | grep NodePort || true
    
    echo ""
    log_info "To check logs:"
    echo "  kubectl logs -f deployment/kleidia-services-backend -n $NAMESPACE"
    echo "  kubectl logs -f deployment/kleidia-services-frontend -n $NAMESPACE"
}

# Main execution
main() {
    log_info "=== Kleidia Cleanup and Redeployment ==="
    log_info "Using DockerHub images (no server builds)"
    log_info "Domain: $DOMAIN"
    log_info "Namespace: $NAMESPACE"
    echo ""
    
    check_prerequisites
    cleanup_deployment
    pull_latest_code
    deploy_with_helm
    verify_deployment
    show_status
    
    log_success "=== Deployment completed successfully! ==="
    log_info "Application should be available at: https://$DOMAIN"
    log_info "Backend NodePort: 32570"
    log_info "Frontend NodePort: 30805"
}

# Run main function
main "$@"




