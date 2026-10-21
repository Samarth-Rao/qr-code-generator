#!/bin/bash

# QR Code Generator - Kind Deployment Script
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🚀 Starting QR Code Generator deployment to Kind..."

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

# Check if Kind is installed
if ! command -v kind &> /dev/null; then
    print_error "Kind is not installed. Please install Kind first:"
    echo "   brew install kind"
    exit 1
fi

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

# Create Kind cluster if it doesn't exist
CLUSTER_NAME="qr-generator-cluster"
if ! kind get clusters | grep -q "$CLUSTER_NAME"; then
    print_status "Creating Kind cluster: $CLUSTER_NAME"
    kind create cluster --name "$CLUSTER_NAME" --config "$SCRIPT_DIR/kind-config.yaml"
    print_success "Kind cluster created successfully"
else
    print_status "Kind cluster '$CLUSTER_NAME' already exists"
fi

# Build Docker image
print_status "Building Docker image..."
docker build -t qr-generator:latest .
print_success "Docker image built successfully"

# Load image into Kind cluster
print_status "Loading Docker image into Kind cluster..."
kind load docker-image qr-generator:latest --name "$CLUSTER_NAME"
print_success "Docker image loaded into Kind cluster"

# Install NGINX Ingress Controller
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

# Apply Kubernetes manifests
print_status "Applying Kubernetes manifests..."
kubectl apply -k k8s/
print_success "Kubernetes manifests applied"

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
echo "127.0.0.1 qr-generator.local" | sudo tee -a /etc/hosts > /dev/null 2>&1 || \
echo "127.0.0.1 qr-generator.local" >> /tmp/hosts && \
print_warning "Please add '127.0.0.1 qr-generator.local' to your /etc/hosts file manually"

# Display access information
echo ""
print_success "🎉 QR Code Generator deployed successfully!"
echo ""
echo "📱 Access your application:"
echo "   Web Interface: http://qr-generator.local"
echo "   Direct Service: http://localhost:30080"
echo ""
echo "🔧 Useful commands:"
echo "   View pods: kubectl get pods -n qr-generator"
echo "   View logs: kubectl logs -f deployment/qr-generator -n qr-generator"
echo "   View service: kubectl get svc -n qr-generator"
echo "   Delete cluster: kind delete cluster --name $CLUSTER_NAME"
echo ""
echo "📊 Monitor the deployment:"
echo "   kubectl get all -n qr-generator"
echo "" 