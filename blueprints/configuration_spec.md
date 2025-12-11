# Configuration Management Specification

## 1. Objective
Add centralized configuration management to the existing Helm chart deployment. 
We need two distinct configuration sets available to **both** the API Service and the Spark Job:
1.  **Global Settings**: Environment-wide settings (e.g., env type, region, common constants).
2.  **App Configuration**: Application-specific logic configurations (e.g., timeouts, business rules, shared resource identifiers).

## 2. Architecture

### 2.1 Centralized ConfigMaps
We will introduce two new ConfigMaps in the **Umbrella Chart** (`deploy/charts`). This ensures that configurations are defined once and propagated to all subcharts.

1.  `global-settings-cm`: Sources `deploy/charts/configs/global.conf`.
2.  `app-config-cm`: Sources `deploy/charts/configs/application.conf`.

### 2.2 Directory Structure Upgrade
```
deploy/charts/
├── Chart.yaml
├── values.yaml          <-- Specifies config file paths (optional)
├── configs/             <-- [NEW] Directory for local HOCON files
│   ├── global.conf
│   └── application.conf
├── templates/
│   ├── global-configmap.yaml  <-- Sources configs/global.conf
│   └── app-configmap.yaml     <-- Sources configs/application.conf
└── charts/
    ├── spark-job/
    └── api-service/
```

## 3. Implementation Details

### 3.1 Values Configuration (Umbrella `values.yaml`)
We will add sections to define the actual content of these configurations.

```yaml
# deploy/charts/values.yaml

# Configuration is now sourced directly from files in deploy/charts/configs/
# No inline config here.
global:
  configMapNames:
    settings: "{{ .Release.Name }}-global-settings"
    appConfig: "{{ .Release.Name }}-app-config"

```

### 3.2 ConfigMap Templates
The umbrella chart will render these ConfigMaps.

**Templates/global-configmap.yaml**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Values.global.configMapNames.settings }}
data:
  global.conf: |
{{ .Files.Get "configs/global.conf" | indent 4 }}
```

**Templates/app-configmap.yaml**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Values.global.configMapNames.appConfig }}
data:
  application.conf: |
{{ .Files.Get "configs/application.conf" | indent 4 }}
```

### 3.3 Consuming Configuration (Subcharts)

Subcharts (`spark-job` and `api-service`) need to know the *names* of these ConfigMaps to mount them. We can rely on a naming convention or pass the names down via global values. Passing names is safer.

**Update `values.yaml` (Global section)**:
```yaml
global:
  configMapNames:
    settings: "{{ .Release.Name }}-global-settings"
    appConfig: "{{ .Release.Name }}-app-config"
```

**Subchart Deployment (e.g., `api-service/deployment.yaml`)**:
```yaml
# Mounting Global Settings
volumeMounts:
  - name: global-config-vol
    mountPath: /etc/config/global
    readOnly: true
  - name: app-config-vol
    mountPath: /etc/config/app
    readOnly: true

volumes:
  - name: global-config-vol
    configMap:
      name: {{ .Values.global.configMapNames.settings }}
  - name: app-config-vol
    configMap:
      name: {{ .Values.global.configMapNames.appConfig }}
```

**Spark Job Consideration**:
For Spark, mount both volumes.
- **Spark Submit Flags**:
  - Point to the app config: `--conf spark.driver.extraJavaOptions="-Dconfig.file=/etc/config/app/application.conf"`
  - Ensure `application.conf` can resolve the include `/etc/config/global/global.conf`.
- **K8s Volume Mounts**:
  - `spark.kubernetes.driver.volumes.[hostPath/persistentVolumeClaim/emptyDir].name`? No, use ConfigMap volumes.
  - `spark.kubernetes.driver.volumes.configMap.global-config.options.name={{ .Values.global.configMapNames.settings }}`
  - `spark.kubernetes.driver.volumes.configMap.global-config.mount.path=/etc/config/global`
  - Same for `app-config`.

## 4. Work Plan
1.  **Define Configuration Schema**: Finalize what keys go into Global vs App config.
2.  **Create Umbrella Templates**: Add the two ConfigMap templates to `deploy/charts/templates/`.
3.  **Update Umbrella Values**: Add default values for settings and app config.
4.  **Update Subcharts**: Modify `spark-job` and `api-service` deployments to mount these maps.
