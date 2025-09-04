# Global Blue/Green Deployments with Upbound Crossplane and k8gb

An Upbound DevX configuration package that enables global blue/green deployments across geographically distributed Kubernetes clusters using k8gb. This configuration provides automatic active/passive cluster switching with Azure infrastructure and intelligent GSLB health monitoring.

## Features

- **Global Blue/Green**: Automatic active/passive cluster switching based on health
- **Azure Infrastructure**: Resource Groups and Redis Cache for application state
- **Application Deployment**: Podinfo with k8gb integration via Helm
- **GSLB Health Monitoring**: Intelligent traffic routing and failover
- **Upbound DevX**: Modern embedded functions with KCL-based composition logic
- **Auto-Policy Management**: Hands-off blue/green switching with policy automation
- **Crossplane v2**: Compatible with namespace-scoped `.m.upbound.io` resources

## Prerequisites

### k8gb Installation Required

**Important**: k8gb must be pre-installed on your Kubernetes clusters for proper GSLB functionality. This configuration creates k8gb `Gslb` resources but does not install the k8gb operator itself.

```bash
# Install k8gb using Helm
helm repo add k8gb https://www.k8gb.io
helm install k8gb k8gb/k8gb --namespace k8gb --create-namespace
```

See [k8gb installation guide](https://www.k8gb.io/docs/install.html) for detailed setup instructions.

### Other Dependencies

- **Crossplane** >= v2 with v2 composition mode
- **Azure credentials** configured as Kubernetes secrets
- **DNS delegation** configured for k8gb domains
- **Ingress controller** (nginx recommended)

## Installation

1. **Install the configuration**:
   ```bash
   kubectl apply -f - <<EOF
   apiVersion: pkg.crossplane.io/v1
   kind: Configuration
   metadata:
     name: configuration-k8gb-bluegreen
   spec:
     package: xpkg.upbound.io/solutions/configuration-k8gb-bluegreen:latest
   EOF
   ```

2. **Configure Azure credentials**:
   ```bash
   # Create Azure service principal credentials file
   cat > azure-credentials.json <<EOF
   {
     "clientId": "your-client-id",
     "clientSecret": "your-client-secret", 
     "subscriptionId": "your-subscription-id",
     "tenantId": "your-tenant-id"
   }
   EOF
   
   # Create Kubernetes secret
   kubectl create secret generic azure-creds \
     -n crossplane-system \
     --from-file=credentials=./azure-credentials.json
   ```

3. **Apply the ClusterProviderConfig**:
   ```bash
   kubectl apply -f examples/providerconfig-azure.yaml
   ```

## Examples

### Basic GlobalApp

Create a basic global application with manual policy management:

```yaml
apiVersion: example.upbound.io/v1alpha1
kind: GlobalApp
metadata:
  name: my-global-app
  namespace: default
spec:
  region: "West Europe"
  primaryGeoTag: "eu"
  hostname: "myapp.example.com"
  managementPolicies: ["*"]
  autoApplyRecommendedPolicy: false
```

### Auto-Policy GlobalApp

Create a global application with automatic active/passive switching:

```yaml
apiVersion: example.upbound.io/v1alpha1
kind: GlobalApp
metadata:
  name: auto-global-app  
  namespace: default
spec:
  region: "East US"
  primaryGeoTag: "us" 
  hostname: "auto-app.example.com"
  managementPolicies: ["*"]
  autoApplyRecommendedPolicy: true  # Automatic policy switching
```

## Configuration Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `region` | Azure region for infrastructure | `"West US"` |
| `primaryGeoTag` | Primary geographic tag for GSLB failover | `"eu"` |
| `hostname` | Application hostname for ingress | `"globalapp.cloud.example.com"` |
| `managementPolicies` | Crossplane management policies | `["*"]` |
| `autoApplyRecommendedPolicy` | Enable automatic policy switching | `false` |

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Cluster A     │    │   Cluster B     │    │   Cluster C     │
│  (Primary EU)   │    │ (Secondary US)  │    │ (Secondary AS)  │
├─────────────────┤    ├─────────────────┤    ├─────────────────┤
│ GlobalApp XR    │    │ GlobalApp XR    │    │ GlobalApp XR    │
│ ├─Azure RG      │    │ ├─Azure RG      │    │ ├─Azure RG      │
│ ├─Redis Cache   │    │ ├─Redis Cache   │    │ ├─Redis Cache   │
│ ├─Podinfo App   │    │ ├─Podinfo App   │    │ ├─Podinfo App   │
│ └─k8gb GSLB     │    │ └─k8gb GSLB     │    │ └─k8gb GSLB     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │   DNS/GSLB      │
                    │ Traffic Routing │
                    └─────────────────┘
```

## Testing

### Composition Tests

Run the included composition tests:

```bash
up test run tests/*
```

### End-to-End Testing

**Prerequisites**: k8gb must be installed and configured on all clusters.

1. **Deploy test applications** across multiple clusters
2. **Configure DNS delegation** for your test domains
3. **Apply GlobalApp resources** in each cluster
4. **Test failover scenarios**:
   ```bash
   # Check GSLB status
   kubectl get gslb

   # Test DNS resolution
   dig your-app.example.com

   # Simulate cluster failure
   kubectl scale deployment podinfo --replicas=0
   ```

### Local Development

For local development and testing:

```bash
# Build and test locally
up project build
up test run tests/*

# Run composition rendering tests
up composition render apis/globalapp/composition.yaml examples/globalapp/example.yaml --xrd=apis/globalapp/definition.yaml
```

## Status Monitoring

The GlobalApp provides comprehensive status information:

```bash
kubectl get globalapp my-global-app -o yaml
```

**Status fields**:
- `infrastructure`: Azure resource deployment status
- `application`: Podinfo and GSLB resource status  
- `gslb`: Health monitoring and policy recommendations

## 🚀 Multi-Cluster Blue/Green Demo

### Complete Local Setup

Set up a full local multi-cluster environment to demonstrate blue/green deployments:

#### 1. **Prepare k8gb Test Environment**
```bash
# Clone and set up k8gb test environment
git clone https://github.com/k8gb-io/k8gb
cd k8gb
git checkout v0.15.0
make deploy-full-local-setup
```

#### 2. **Install Configuration Package**
```bash
# Clone this configuration
git clone https://github.com/upbound/configuration-k8gb-bluegreen.git
cd configuration-k8gb-bluegreen

# Switch to EU cluster (Blue environment)
kubectl config use-context k3d-test-gslb1
up uxp install

# Install the configuration package
kubectl apply -f examples/configuration.yaml
kubectl get configurations
```

#### 3. **Configure Providers**
```bash
# Set up Azure credentials
kubectl create secret generic azure-creds -n crossplane-system \
  --from-literal=credentials="$(cat ~/.azure/credentials.json)"

# Apply provider configurations and RBAC
kubectl apply -f examples/providerconfig-helm.yaml
kubectl apply -f examples/providerconfig-azure.yaml
kubectl apply -f examples/rbac-k8gb.yaml
```

#### 4. **Deploy Blue Environment (EU - Active)**
```bash
# Deploy blue environment
kubectl apply -f examples/globalapp/blue-active.yaml

# Monitor deployment
crossplane beta trace globalapps.example.upbound.io/blue-green
kubectl get globalapps.example.upbound.io blue-green

# Check blue environment status
kubectl get globalapps.example.upbound.io blue-green -o yaml | yq
```

#### 5. **Deploy Green Environment (US - Passive)**
```bash
# Switch to US cluster
kubectl config use-context k3d-test-gslb2
up uxp install
kubectl apply -f examples/configuration.yaml

# Set up providers (repeat provider setup from step 3)
# ...

# Deploy green environment
kubectl apply -f examples/globalapp/green-passive.yaml

# Check green environment status
kubectl get globalapps.example.upbound.io blue-green -o yaml | yq
```

#### 6. **🔄 Test Blue/Green Failover**
```bash
# Simulate blue environment failure
kubectl config use-context k3d-test-gslb1
kubectl scale deployment podinfo-blue-green --replicas=0

# Watch GSLB detect failure and policy changes
kubectl get globalapps.example.upbound.io blue-green -o yaml | yq '.status.gslb'

# Switch to green cluster - check if it's now active  
kubectl config use-context k3d-test-gslb2
kubectl get globalapps.example.upbound.io blue-green -o yaml | yq '.status.gslb'
```

### 📊 **Blue/Green Status Monitoring**

Monitor the automatic failover process:

```bash
# View complete GlobalApp status (infrastructure, application, gslb)
kubectl get globalapps.example.upbound.io blue-green -o yaml | yq '.status'

# View just GSLB status (health, policies, active cluster)
kubectl get globalapps.example.upbound.io blue-green -o yaml | yq '.status.gslb'

# View k8gb GSLB resources directly
kubectl get gslb -A
kubectl describe gslb failover-ingress-blue-green
```

## Troubleshooting

### Common Issues

1. **k8gb not installed**: Ensure k8gb operator is running in all clusters
2. **DNS not configured**: Configure DNS delegation for GSLB domains
3. **Azure credentials**: Verify ClusterProviderConfig and secret configuration
4. **Network connectivity**: Ensure clusters can communicate for health checks

### Debug Commands

```bash
# Check resource status
crossplane beta trace globalapp.example.upbound.io/my-global-app

# Check k8gb status
kubectl get gslb -A
kubectl describe gslb failover-ingress-blue-green

# Check provider status
kubectl get providers
kubectl get clusterproviderconfigs
```
