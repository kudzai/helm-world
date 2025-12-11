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
    
  # [Optional] External ConfigMaps reference
  # If set, the chart will NOT create the ConfigMaps, but use these instead.
  # This allows parent charts to provide their own configs.
  externalConfigMaps:
    settings: ""
    appConfig: ""
```

### 3.2 ConfigMap Templates
The umbrella chart will render these ConfigMaps **only if externalConfigMaps is not set**.

**Templates/global-configmap.yaml**
```yaml
{{- if not .Values.global.externalConfigMaps.settings }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Values.global.configMapNames.settings }}
data:
  global.conf: |
{{ .Files.Get "configs/global.conf" | indent 4 }}
{{- end }}
```

**Templates/app-configmap.yaml**
```yaml
{{- if not .Values.global.externalConfigMaps.appConfig }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Values.global.configMapNames.appConfig }}
data:
  application.conf: |
{{ .Files.Get "configs/application.conf" | indent 4 }}
{{- end }}
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
      # Use external map if provided, otherwise default to generated one
      name: {{ .Values.global.externalConfigMaps.settings | default .Values.global.configMapNames.settings }}
  - name: app-config-vol
    configMap:
      name: {{ .Values.global.externalConfigMaps.appConfig | default .Values.global.configMapNames.appConfig }}
```

## 4. Domain Team Usage (Pattern)

When a Domain Team depends on this chart, they should prevent the base chart from creating generic configs and instead inject their own.

**Domain Chart Structure:**
```
domain-chart/
├── Chart.yaml (dependencies: - name: base-chart)
├── templates/
│   ├── my-global-config.yaml
│   └── my-app-config.yaml
├── configs/
│   ├── global.conf
│   └── application.conf
└── values.yaml
```

**Domain Chart `values.yaml`:**
```yaml
base-chart:
  global:
    externalConfigMaps:
      settings: "my-domain-global-settings"
      appConfig: "my-domain-app-config"
```

**Domain Chart `templates/my-global-config.yaml`:**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-domain-global-settings
data:
  global.conf: |
{{ .Files.Get "configs/global.conf" | indent 4 }}
```

This pattern allows the Domain Team to maintain their config files as real files in their source control, rather than strings in `values.yaml`.
