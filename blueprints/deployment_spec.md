# Deployment Specification: Spark Job & Service

## 1. Executive Summary
This document outlines the deployment strategy for a Spark execution environment ("Spark Job") and an API service ("Service") on OpenShift. The goal is to provide a flexible Helm-based deployment that allows deploying both components together or the Spark cluster independently.

## 2. Architecture Overview
The system consists of two primary logical components deployed into a shared OpenShift namespace:

1.  **Spark Cluster (Project `job`)**:
    *   **Spark Master**: A pod managed by a Deployment/StatefulSet that coordinates the job.
    *   **Spark Workers**: A scalable set of pods managed by a Deployment, registered with the Master.
    *   **Docker Image**: Single image shared by Master and Workers.
2.  **API Service (Project `service`)**:
    *   **Service Pods**: Stateless API service managed by a Deployment.
    *   **Exposition**: Exposed via OpenShift Route/Ingress.
    *   **Auth**: OAuth integration for client requests.
    *   **Interaction**: Submits jobs to the Spark Master URL.

## 3. Helm Chart Strategy
We will use the **Umbrella Chart Pattern** to achieve the requirement of unified or independent deployments.

### 3.1 Directory Structure
```
deploy/
└── charts/
    ├── Chart.yaml (Umbrella Chart)
    ├── values.yaml (Global defaults)
    └── charts/ (Subcharts)
        ├── spark-job/
        │   ├── Chart.yaml
        │   ├── templates/
        │   └── values.yaml
        └── api-service/
            ├── Chart.yaml
            ├── templates/
            └── values.yaml
```

### 3.2 Component Details

#### A. Spark Job Subchart (`spark-job`)
**Values Configuration:**
```yaml
image:
  repository: my-registry/spark-job
  tag: latest
spark:
  master:
    port: 7077
    webUiPort: 8080
    resources: { ... }
  worker:
    replicas: 2  # Configurable number of workers
    resources: { ... }
```

**Templates:**
1.  `master-deployment.yaml`: Deploys the Spark Master.
2.  `master-service.yaml`: Headless service for worker discovery (port 7077) and UI (port 8080).
3.  `worker-deployment.yaml`: Deploys N workers. Includes env var `SPARK_MASTER_URL` pointing to the master service.

#### B. API Service Subchart (`api-service`)
**Values Configuration:**
```yaml
image:
  repository: my-registry/api-service
  tag: latest
oauth:
  enabled: true
  clientId: "..."
  # ... other oauth configs
env:
  sparkMasterUrl: "spark://spark-master:7077" # Default pointer to sibling chart
```

**Templates:**
1.  `deployment.yaml`: The API service pods.
2.  `service.yaml`: ClusterIP service for the API.
3.  `route.yaml` (or Ingress): OpenShift Route for external access with TLS termination.
4.  `oauth-proxy.yaml` (Optional): If using a sidecar for OAuth, or configuration for internal handling.

### 3.3 Parent (Umbrella) Configuration
The parent `values.yaml` will control the subcharts using specific keys and global tags.

```yaml
# deploy/charts/values.yaml

# Toggle deployments
tags:
  install-spark: true
  install-service: true

# Overrides for Subcharts
spark-job:
  spark:
    worker:
      replicas: 4 # Override default 2

api-service:
  env:
    # Ensure it points to the spark master service name defined in spark-job
    sparkMasterUrl: "spark://{{ .Release.Name }}-spark-master:7077"
```

## 4. Deployment Scenarios

### Scenario 1: Full Stack Deployment
Deploy everything together.
```bash
helm install full-stack ./deploy/charts
```

### Scenario 2: Spark Cluster Only
Deploy only the spark cluster (e.g., for manual testing or scaling independently).
```bash
helm install spark-cluster ./deploy/charts \
  --set tags.install-service=false
```

### Scenario 3: Service Only (Advanced)
If connecting to an external or existing spark cluster.
```bash
helm install my-service ./deploy/charts \
  --set tags.install-spark=false \
  --set api-service.env.sparkMasterUrl="spark://external-master:7077"
```

## 5. Next Steps
1.  Initialize the Helm directory structure.
2.  Implement `spark-job` templates.
3.  Implement `api-service` templates including OAuth sidecar/config.
4.  Create the umbrella Chart.yaml and values.yaml.
