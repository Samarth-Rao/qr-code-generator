# QR Code Generator API

A modern FastAPI application that generates QR codes from text, URLs, or any other data. Features a beautiful web interface and RESTful API endpoints.

## Features

- 🎨 **Beautiful Web Interface**: Modern, responsive design with gradient backgrounds and smooth animations
- 🔧 **Customizable QR Codes**: Adjust size and box size parameters
- 📱 **Mobile Friendly**: Responsive design that works on all devices
- 🚀 **Fast API**: Built with FastAPI for high performance
- 📥 **Download Support**: Direct download of generated QR codes
- 🔍 **API Documentation**: Automatic OpenAPI/Swagger documentation
- 🏥 **Health Check**: Built-in health monitoring endpoint
- ☸️ **Kubernetes Ready**: Full Kubernetes deployment support with Kind

## Quick Start

### Local Development

1. **Clone or download the project files**

2. **Install dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

3. **Run the application**:
   ```bash
   python main.py
   ```

   Or using uvicorn directly:
   ```bash
   uvicorn main:app --host 0.0.0.0 --port 8000 --reload
   ```

4. **Open your browser** and navigate to `http://localhost:8000`

### Kubernetes Deployment with Kind

#### Prerequisites

- [Docker](https://docs.docker.com/get-docker/) installed and running
- [Kind](https://kind.sigs.k8s.io/docs/user/quick-start/) installed
- [kubectl](https://kubernetes.io/docs/tasks/tools/) installed

Install Kind and kubectl on macOS:
```bash
brew install kind kubectl
```

#### Deploy to Kind

1. **Run the deployment script**:
   ```bash
   ./deploy.sh
   ```

   This script will:
   - Create a Kind cluster with 3 nodes (1 control-plane, 2 workers)
   - Build and load the Docker image
   - Install NGINX Ingress Controller
   - Deploy the application with all Kubernetes resources
   - Set up networking and access

2. **Access your application**:
   - Web Interface: http://qr-generator.local
   - Direct Service: http://localhost:30080
   - API Documentation: http://qr-generator.local/docs

#### Cleanup

To remove the Kind cluster and clean up resources:
```bash
./cleanup.sh
```

#### Manual Deployment Steps

If you prefer to deploy manually:

1. **Create Kind cluster**:
   ```bash
   kind create cluster --name qr-generator-cluster
   ```

2. **Build and load Docker image**:
   ```bash
   docker build -t qr-generator:latest .
   kind load docker-image qr-generator:latest --name qr-generator-cluster
   ```

3. **Install NGINX Ingress Controller**:
   ```bash
   kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
   ```

4. **Deploy application**:
   ```bash
   kubectl apply -k k8s/
   ```

5. **Add host entry**:
   ```bash
   echo "127.0.0.1 qr-generator.local" | sudo tee -a /etc/hosts
   ```

## Usage

### Web Interface

1. Visit the application URL in your browser
2. Enter the text, URL, or data you want to encode
3. Adjust size and box size settings (optional)
4. Click "Generate QR Code"
5. Download the generated QR code

### API Endpoints

#### 1. Web Interface
- **GET** `/` - Main web interface

#### 2. Generate QR Code (Advanced)
- **POST** `/generate-qr`
  - **Parameters**:
    - `data` (string, required): Text, URL, or data to encode
    - `size` (integer, optional): Size in pixels (100-500, default: 200)
    - `box_size` (integer, optional): Box size (1-20, default: 10)
  - **Response**: JSON with QR code URL and metadata

#### 3. Generate QR Code (Simple)
- **GET** `/generate-qr-simple?data=your_text`
  - **Parameters**:
    - `data` (string, required): Text, URL, or data to encode
  - **Response**: Direct PNG image file

#### 4. Health Check
- **GET** `/health` - Application health status

#### 5. API Documentation
- **GET** `/docs` - Interactive API documentation (Swagger UI)
- **GET** `/redoc` - Alternative API documentation

## API Examples

### Using curl

**Generate QR code with custom settings:**
```bash
curl -X POST "http://localhost:8000/generate-qr" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "data=https://example.com&size=300&box_size=15"
```

**Generate simple QR code:**
```bash
curl "http://localhost:8000/generate-qr-simple?data=Hello%20World" \
  --output qr_code.png
```

### Using Python requests

```python
import requests

# Generate QR code with custom settings
response = requests.post(
    "http://localhost:8000/generate-qr",
    data={
        "data": "https://example.com",
        "size": 300,
        "box_size": 15
    }
)
result = response.json()
print(f"QR Code URL: {result['qr_code_url']}")

# Download simple QR code
response = requests.get(
    "http://localhost:8000/generate-qr-simple",
    params={"data": "Hello World"}
)
with open("qr_code.png", "wb") as f:
    f.write(response.content)
```

## Kubernetes Architecture

The application is deployed with the following Kubernetes resources:

- **Namespace**: `qr-generator` - Isolates the application
- **ConfigMap**: `qr-generator-config` - Application configuration
- **Deployment**: `qr-generator` - Application pods with 2 replicas
- **Service**: `qr-generator-service` - Internal load balancing
- **Ingress**: `qr-generator-ingress` - External access with NGINX

### Monitoring and Management

```bash
# View all resources
kubectl get all -n qr-generator

# View pod logs
kubectl logs -f deployment/qr-generator -n qr-generator

# Scale deployment
kubectl scale deployment qr-generator --replicas=3 -n qr-generator

# Port forward for direct access
kubectl port-forward svc/qr-generator-service 8080:80 -n qr-generator
```

## Configuration

The application uses sensible defaults, but you can modify the following:

### Environment Variables
- `APP_HOST`: Application host (default: 0.0.0.0)
- `APP_PORT`: Application port (default: 8000)
- `DEFAULT_QR_SIZE`: Default QR code size (default: 200)
- `DEFAULT_BOX_SIZE`: Default box size (default: 10)

### Kubernetes Configuration
- **Replicas**: 2 (configurable in `k8s/deployment.yaml`)
- **Resources**: 128Mi memory, 100m CPU (requests)
- **Health Checks**: Liveness and readiness probes configured
- **Storage**: EmptyDir volume for QR code storage

## File Structure

```
QR Code Generator/
├── main.py              # Main FastAPI application
├── requirements.txt     # Python dependencies
├── Dockerfile          # Docker container configuration
├── .dockerignore       # Docker build exclusions
├── deploy.sh           # Kind deployment script
├── cleanup.sh          # Kind cleanup script
├── README.md           # This file
├── k8s/                # Kubernetes manifests
│   ├── namespace.yaml
│   ├── configmap.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   └── kustomization.yaml
└── static/             # Generated QR codes (created automatically)
```

## Dependencies

- **FastAPI**: Modern web framework for building APIs
- **Uvicorn**: ASGI server for running FastAPI
- **qrcode**: QR code generation library
- **Pillow**: Python Imaging Library for image processing
- **python-multipart**: For handling form data

## Development

To run in development mode with auto-reload:

```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

## Production Deployment

For production deployment, consider:

1. Using a production ASGI server like Gunicorn with Uvicorn workers
2. Setting up proper logging
3. Implementing rate limiting
4. Adding authentication if needed
5. Using environment variables for configuration
6. Setting up persistent storage for QR codes
7. Configuring proper ingress with SSL/TLS

Example production command:
```bash
gunicorn main:app -w 4 -k uvicorn.workers.UvicornWorker --bind 0.0.0.0:8000
```

## Troubleshooting

### Common Issues

1. **Port already in use**: Change the port in the service or deployment
2. **Image pull errors**: Ensure the Docker image is built and loaded into Kind
3. **Ingress not working**: Check if NGINX Ingress Controller is installed and running
4. **Host resolution**: Ensure the host entry is added to `/etc/hosts`

### Debug Commands

```bash
# Check pod status
kubectl get pods -n qr-generator

# View pod logs
kubectl logs <pod-name> -n qr-generator

# Describe resources
kubectl describe pod <pod-name> -n qr-generator

# Check ingress status
kubectl get ingress -n qr-generator

# Test service connectivity
kubectl run test-pod --image=busybox --rm -it --restart=Never -- nslookup qr-generator-service
```

## License

This project is open source and available under the MIT License.

## Contributing

Feel free to submit issues and enhancement requests! 

pack build qr-generator:latest --builder paketobuildpacks/builder:base 