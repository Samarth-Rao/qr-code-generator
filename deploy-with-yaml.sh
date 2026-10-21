#!/bin/bash

# QR Code Generator - YAML-based Deployment Script
set -e

echo "🚀 Starting QR Code Generator deployment using YAML files..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed. Please install kubectl first:"
    echo "   brew install kubectl"
    exit 1
fi

# Check if Docker is running
if ! docker info &> /dev/null; then
    print_error "Docker is not running. Please start Docker first."
    exit 1
fi

# Get current context
CURRENT_CONTEXT=$(kubectl config current-context)
print_status "Current kubectl context: $CURRENT_CONTEXT"

# Build Docker image using pack
print_status "Building Docker image using pack..."
if command -v pack &> /dev/null; then
    pack build qr-generator:latest --builder paketobuildpacks/builder-jammy-base
    print_success "Docker image built successfully with pack"
else
    print_warning "pack not found, building with Docker..."
    docker build -t qr-generator:latest .
    print_success "Docker image built successfully with Docker"
fi

# Load image into Kind cluster
print_status "Loading Docker image into Kind cluster..."
CLUSTER_NAME=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}' | sed 's/kind-//')
if [ -n "$CLUSTER_NAME" ]; then
    kind load docker-image qr-generator:latest --name "$CLUSTER_NAME"
    print_success "Docker image loaded into Kind cluster: $CLUSTER_NAME"
else
    print_warning "Could not determine Kind cluster name, skipping image load"
fi

# Install NGINX Ingress Controller if not present
print_status "Checking NGINX Ingress Controller..."
if ! kubectl get namespace ingress-nginx &> /dev/null; then
    print_status "Installing NGINX Ingress Controller..."
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
    print_success "NGINX Ingress Controller installed"
    
    # Wait for NGINX Ingress Controller to be ready
    print_status "Waiting for NGINX Ingress Controller to be ready..."
    kubectl wait --namespace ingress-nginx \
      --for=condition=ready pod \
      --selector=app.kubernetes.io/component=controller \
      --timeout=120s
    print_success "NGINX Ingress Controller is ready"
else
    print_status "NGINX Ingress Controller already exists"
fi

# Apply Kubernetes manifests in order
print_status "Applying Kubernetes manifests..."

# 1. Create namespace
print_status "Creating namespace..."
kubectl apply -f namespace.yaml
print_success "Namespace created"

# 2. Create RBAC
print_status "Creating RBAC resources..."
kubectl apply -f rbac.yaml
print_success "RBAC resources created"

# 3. Create ConfigMap
print_status "Creating ConfigMap..."
kubectl apply -f configmap.yaml
print_success "ConfigMap created"

# 4. Create Deployment
print_status "Creating Deployment..."
kubectl apply -f deployment.yaml
print_success "Deployment created"

# 5. Create Service
print_status "Creating Service..."
kubectl apply -f service.yaml
print_success "Service created"

# 6. Create Ingress
print_status "Creating Ingress..."
kubectl apply -f ingress.yaml
print_success "Ingress created"

# 7. Create HPA (optional - requires metrics server)
print_status "Creating Horizontal Pod Autoscaler..."
kubectl apply -f hpa.yaml
print_success "HPA created"

# Wait for deployment to be ready
print_status "Waiting for deployment to be ready..."
kubectl wait --namespace qr-generator \
  --for=condition=available \
  --timeout=300s \
  deployment/qr-generator
print_success "Deployment is ready"

# Get service information
print_status "Getting service information..."
kubectl get svc -n qr-generator

# Add host entry for local access
print_status "Adding host entry for local access..."
if ! grep -q "qr-generator.local" /etc/hosts; then
    echo "127.0.0.1 qr-generator.local" | sudo tee -a /etc/hosts > /dev/null 2>&1 || \
    print_warning "Could not add host entry automatically. Please add '127.0.0.1 qr-generator.local' to your /etc/hosts file manually."
    print_success "Host entry added"
else
    print_status "Host entry already exists"
fi

# Display access information
echo ""
print_success "🎉 QR Code Generator deployed successfully!"
echo ""
echo "📱 Access your application:"
echo "   Web Interface: http://qr-generator.local"
echo "   Direct Service: http://localhost:30080"
echo "   API Documentation: http://qr-generator.local/docs"
echo ""
echo "🔧 Useful commands:"
echo "   View all resources: kubectl get all -n qr-generator"
echo "   View pods: kubectl get pods -n qr-generator"
echo "   View logs: kubectl logs -f deployment/qr-generator -n qr-generator"
echo "   View service: kubectl get svc -n qr-generator"
echo "   Scale deployment: kubectl scale deployment qr-generator --replicas=3 -n qr-generator"
echo "   Port forward: kubectl port-forward svc/qr-generator-service 8080:80 -n qr-generator"
echo ""
echo "📊 Monitor the deployment:"
echo "   kubectl get all -n qr-generator"
echo "   kubectl describe deployment qr-generator -n qr-generator"
echo "" 