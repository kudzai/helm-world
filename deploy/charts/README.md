# Spark Job & Service Helm Charts

This directory contains the Helm charts for deploying the Spark Job cluster and the associated API Service on OpenShift.

## Structure

The deployment uses an **Umbrella Chart** pattern:
*   `deploy/charts`: Parent chart.
*   `deploy/charts/charts/spark-job`: Subchart for Spark Master and Workers.
*   `deploy/charts/charts/api-service`: Subchart for the API Service.

## Prerequisites

*   Helm v3+
*   OpenShift CLI (`oc`) or `kubectl` configured with access to your cluster.

## Deployment Scenarios

### 1. Full Stack Deployment (Default)
Deploys both the Spark Cluster and the API Service. The API Service is automatically configured to talk to the Spark Master.

```bash
helm install my-release ./deploy/charts
```

### 2. Spark Cluster Only
Deploys only the Spark Master and Workers. Useful for manual job submission or independent scaling.

```bash
helm install my-spark ./deploy/charts --set tags.install-service=false
```

### 3. API Service Only
Deploys only the API Service. You must provide the URL of an existing Spark Master if it's not the default.

```bash
helm install my-service ./deploy/charts \
  --set tags.install-spark=false \
  --set api-service.env.sparkMasterUrl="spark://existing-master:7077"
```

## Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `tags.install-spark` | Enable deployment of Spark components | `true` |
| `tags.install-service` | Enable deployment of API Service components | `true` |
| `spark-job.spark.worker.replicas` | Number of Spark Worker pods | `2` |
| `spark-job.image.repository` | Spark Job Docker image repository | `my-registry/spark-job` |
| `spark-job.image.tag` | Spark Job Docker image tag | `latest` |
| `api-service.image.repository` | API Service Docker image repository | `my-registry/api-service` |
| `api-service.oauth.clientId` | OAuth Client ID | `api-service-client` |

### Overriding Values
You can override any value using `--set` or a custom `values.yaml` file.

**Example: specific image tags and more workers**
```bash
helm install my-release ./deploy/charts \
  --set spark-job.image.tag=v1.2.3 \
  --set spark-job.spark.worker.replicas=5
```

## Running Example Jobs

You can run the standard Spark Pi example to verify your cluster functionality.

1.  **Get the Spark Master Pod Name:**
    ```bash
    export POD_NAME=$(kubectl get pods -l app.kubernetes.io/component=master -o jsonpath="{.items[0].metadata.name}")
    ```

2.  **Submit the Job:**
    Run `spark-submit` from within the master pod.
    ```bash
    kubectl exec -it $POD_NAME -- /opt/bitnami/spark/bin/spark-submit \
      --class org.apache.spark.examples.SparkPi \
      --master spark://$(kubectl get svc -l app.kubernetes.io/component=master -o jsonpath="{.items[0].metadata.name}"):7077 \
      --conf spark.executor.memory=512m \
      --conf spark.driver.memory=512m \
      /opt/bitnami/spark/examples/jars/spark-examples_2.12-3.5.6.jar \
      1000
    ```
    *Note: Adjust the jar version/path if using a different Spark version. For the configured `bitnamilegacy/spark:3.5.6` image, the Scala version is usually 2.12.*
    *Troubleshooting: If you see "Initial job has not accepted any resources", it means the job is requesting more memory than available on the workers. The flags `--conf spark.executor.memory=512m` ensure it fits within the small 1Gi worker pods.*

## Accessing the Spark Master UI

The Spark Master UI runs on port 8080. Since the service is `ClusterIP` by default, you can access it using port forwarding:

1.  **Port Forward to Localhost:**
    ```bash
    kubectl port-forward svc/$(kubectl get svc -l app.kubernetes.io/component=master -o jsonpath="{.items[0].metadata.name}") 8080:8080
    ```

2.  **Open in Browser:**
    Navigate to [http://localhost:8080](http://localhost:8080).
