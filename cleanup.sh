#!/bin/bash

# QR Code Generator - Cleanup Script
set -e

echo "🧹 Starting cleanup of QR Code Generator from Kind..."

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

CLUSTER_NAME="qr-generator-cluster"

# Check if cluster exists
if ! kind get clusters | grep -q "$CLUSTER_NAME"; then
    print_warning "Kind cluster '$CLUSTER_NAME' does not exist. Nothing to clean up."
    exit 0
fi

# Delete Kubernetes resources
print_status "Deleting Kubernetes resources..."
kubectl delete -k k8s/ --ignore-not-found=true || true
print_success "Kubernetes resources deleted"

# Delete NGINX Ingress Controller
print_status "Deleting NGINX Ingress Controller..."
kubectl delete -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml --ignore-not-found=true || true
print_success "NGINX Ingress Controller deleted"

# Delete Kind cluster
print_status "Deleting Kind cluster: $CLUSTER_NAME"
kind delete cluster --name "$CLUSTER_NAME"
print_success "Kind cluster deleted"

# Remove host entry (optional)
read -p "Do you want to remove the host entry '127.0.0.1 qr-generator.local' from /etc/hosts? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_status "Removing host entry..."
    sudo sed -i '' '/127.0.0.1 qr-generator.local/d' /etc/hosts 2>/dev/null || \
    print_warning "Could not remove host entry automatically. Please remove '127.0.0.1 qr-generator.local' from /etc/hosts manually."
    print_success "Host entry removed"
fi

# Clean up Docker images (optional)
read -p "Do you want to remove the Docker image 'qr-generator:latest'? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_status "Removing Docker image..."
    docker rmi qr-generator:latest 2>/dev/null || print_warning "Docker image not found or already removed"
    print_success "Docker image removed"
fi

print_success "🎉 Cleanup completed successfully!" 