#!/bin/bash
set -e

# YubiMgr Composable Helm Chart Deployment Script
# Deploys the new composable architecture with pure mTLS

NAMESPACE="${NAMESPACE:-kleidia}"
REGISTRY="${REGISTRY:-localhost:5000}"
TIMEOUT="${TIMEOUT:-30m}"

echo "========================================="
echo "YubiMgr Composable Deployment"
echo "========================================="
echo "Namespace: $NAMESPACE"
echo "Registry: $REGISTRY"
echo "Timeout: $TIMEOUT"
echo "========================================="

# Check prerequisites
echo ""
echo "Checking prerequisites..."

if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found"
    exit 1
fi

if ! command -v helm &> /dev/null; then
    echo "❌ helm not found"
    exit 1
fi

echo "✅ Prerequisites OK"

# Check if images exist
echo ""
echo "Checking images..."

if docker images | grep -q "$REGISTRY/kleidia-backend"; then
    echo "✅ Backend image found"
else
    echo "⚠️  Backend image not found at $REGISTRY/kleidia-backend"
    echo "   Build with: cd backend-go && docker build -t $REGISTRY/kleidia-backend:latest . && docker push $REGISTRY/kleidia-backend:latest"
fi

if docker images | grep -q "$REGISTRY/kleidia-frontend"; then
    echo "✅ Frontend image found"
else
    echo "⚠️  Frontend image not found at $REGISTRY/kleidia-frontend"
    echo "   Build with: docker build --pull --no-cache -t $REGISTRY/kleidia-frontend:latest -f frontend/Dockerfile . && docker push $REGISTRY/kleidia-frontend:latest"
fi

# Ask for deployment mode
echo ""
echo "Deployment Options:"
echo "1. Deploy all layers at once (meta chart)"
echo "2. Deploy incrementally (platform → data → services)"
echo ""
read -p "Select option [1 or 2]: " DEPLOY_MODE

if [ "$DEPLOY_MODE" == "1" ]; then
    echo ""
    echo "========================================="
    echo "Deploying all layers via meta chart..."
    echo "========================================="
    
    helm install kleidia ./kleidia-meta \
        --namespace "$NAMESPACE" \
        --create-namespace \
        --wait \
        --timeout "$TIMEOUT" \
        --set global.namespace="$NAMESPACE" \
        --set global.registry.host="$REGISTRY"
    
    echo "✅ Deployment complete!"

elif [ "$DEPLOY_MODE" == "2" ]; then
    echo ""
    echo "========================================="
    echo "Phase 1: Deploying Platform Layer"
    echo "========================================="
    
    helm install kleidia-platform ./kleidia-platform \
        --namespace "$NAMESPACE" \
        --create-namespace \
        --wait \
        --timeout "$TIMEOUT" \
        --set global.namespace="$NAMESPACE" \
        --set global.registry.host="$REGISTRY"
    
    echo "✅ Platform layer deployed!"
    
    echo ""
    echo "========================================="
    echo "Phase 2: Deploying Data Layer"
    echo "========================================="
    
    helm install kleidia-data ./kleidia-data \
        --namespace "$NAMESPACE" \
        --wait \
        --timeout "$TIMEOUT" \
        --set global.namespace="$NAMESPACE" \
        --set global.registry.host="$REGISTRY"
    
    echo "✅ Data layer deployed!"
    
    echo ""
    echo "========================================="
    echo "Phase 3: Deploying Services Layer"
    echo "========================================="
    
    helm install kleidia-services ./kleidia-services \
        --namespace "$NAMESPACE" \
        --wait \
        --timeout "$TIMEOUT" \
        --set global.namespace="$NAMESPACE" \
        --set global.registry.host="$REGISTRY"
    
    echo "✅ Services layer deployed!"
    echo "✅ All layers deployed successfully!"

else
    echo "❌ Invalid option"
    exit 1
fi

# Show deployment status
echo ""
echo "========================================="
echo "Deployment Status"
echo "========================================="

echo ""
echo "Pods:"
kubectl get pods -n "$NAMESPACE"

echo ""
echo "Certificates:"
kubectl get certificate -n "$NAMESPACE"

echo ""
echo "Services:"
kubectl get svc -n "$NAMESPACE"

echo ""
echo "========================================="
echo "✅ YubiMgr Deployed Successfully!"
echo "========================================="
echo ""
echo "Next steps:"
echo "1. Check Vault status: kubectl exec -it vault-0 -n $NAMESPACE -- vault status"
echo "2. View backend logs: kubectl logs -n $NAMESPACE deployment/backend"
echo "3. Access frontend: kubectl get svc frontend -n $NAMESPACE"
echo ""

