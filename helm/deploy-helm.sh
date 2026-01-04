#!/bin/bash
# YubiMgr Helm Deployment Script
# This script replaces the complex bash-based deployment with Helm

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHART_DIR="$SCRIPT_DIR/../helm/kleidia"
RELEASE_NAME="kleidia"
NAMESPACE="kleidia"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
    
    # Check if Helm is installed
    if ! command -v helm &> /dev/null; then
        log_error "Helm is not installed. Please install Helm 3.0+"
        exit 1
    fi
    
    # Check Helm version
    HELM_VERSION=$(helm version --template='{{.Version}}' | sed 's/v//')
    log_info "Helm version: $HELM_VERSION"
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed. Please install kubectl"
        exit 1
    fi
    
    # Check if chart directory exists
    if [ ! -d "$CHART_DIR" ]; then
        log_error "Chart directory not found: $CHART_DIR"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Validate chart
validate_chart() {
    log_info "Validating Helm chart..."
    
    if ! helm lint "$CHART_DIR"; then
        log_error "Chart validation failed"
        exit 1
    fi
    
    log_success "Chart validation passed"
}

# Check if release exists
check_release() {
    if helm list -n "$NAMESPACE" | grep -q "$RELEASE_NAME"; then
        return 0
    else
        return 1
    fi
}

# Install or upgrade release
deploy_release() {
    local values_file="$1"
    
    if check_release; then
        log_info "Upgrading existing release: $RELEASE_NAME"
        helm upgrade "$RELEASE_NAME" "$CHART_DIR" \
            --namespace "$NAMESPACE" \
            --create-namespace \
            --values "$values_file" \
            --wait \
            --timeout 10m
    else
        log_info "Installing new release: $RELEASE_NAME"
        helm install "$RELEASE_NAME" "$CHART_DIR" \
            --namespace "$NAMESPACE" \
            --create-namespace \
            --values "$values_file" \
            --wait \
            --timeout 10m
    fi
}

# Run tests
run_tests() {
    log_info "Running Helm tests..."
    
    if helm test "$RELEASE_NAME" --namespace "$NAMESPACE"; then
        log_success "All tests passed"
    else
        log_warning "Some tests failed, but deployment may still be functional"
    fi
}

# Show status
show_status() {
    log_info "Deployment status:"
    helm status "$RELEASE_NAME" --namespace "$NAMESPACE"
    
    log_info "Pod status:"
    kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/instance="$RELEASE_NAME"
    
    log_info "Service status:"
    kubectl get services -n "$NAMESPACE" -l app.kubernetes.io/instance="$RELEASE_NAME"
}

# Main deployment function
deploy() {
    local environment="${1:-production}"
    local values_file=""
    
    case "$environment" in
        "production")
            values_file="$CHART_DIR/values-production.yaml"
            ;;
        "development")
            values_file="$CHART_DIR/values-development.yaml"
            ;;
        "custom")
            values_file="$2"
            if [ -z "$values_file" ] || [ ! -f "$values_file" ]; then
                log_error "Custom values file not specified or not found: $values_file"
                exit 1
            fi
            ;;
        *)
            log_error "Invalid environment: $environment"
            log_info "Valid environments: production, development, custom"
            exit 1
            ;;
    esac
    
    log_info "Starting YubiMgr deployment..."
    log_info "Environment: $environment"
    log_info "Values file: $values_file"
    
    check_prerequisites
    validate_chart
    deploy_release "$values_file"
    run_tests
    show_status
    
    log_success "YubiMgr deployment completed successfully!"
}

# Uninstall function
uninstall() {
    log_info "Uninstalling YubiMgr..."
    
    if check_release; then
        helm uninstall "$RELEASE_NAME" --namespace "$NAMESPACE"
        log_success "YubiMgr uninstalled successfully"
    else
        log_warning "Release $RELEASE_NAME not found"
    fi
}

# Show usage
usage() {
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  deploy [environment]     Deploy YubiMgr (production|development|custom)"
    echo "  uninstall              Uninstall YubiMgr"
    echo "  status                 Show deployment status"
    echo "  test                   Run Helm tests"
    echo "  lint                   Validate Helm chart"
    echo ""
    echo "Examples:"
    echo "  $0 deploy production"
    echo "  $0 deploy development"
    echo "  $0 deploy custom /path/to/values.yaml"
    echo "  $0 uninstall"
    echo "  $0 status"
}

# Main script logic
case "${1:-deploy}" in
    "deploy")
        deploy "$2" "$3"
        ;;
    "uninstall")
        uninstall
        ;;
    "status")
        show_status
        ;;
    "test")
        run_tests
        ;;
    "lint")
        validate_chart
        ;;
    "help"|"-h"|"--help")
        usage
        ;;
    *)
        log_error "Unknown command: $1"
        usage
        exit 1
        ;;
esac
