{{/*
Expand the name of the chart.
*/}}
{{- define "spark-job.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "spark-job.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "spark-job.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "spark-job.labels" -}}
helm.sh/chart: {{ include "spark-job.chart" . }}
{{ include "spark-job.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "spark-job.selectorLabels" -}}
app.kubernetes.io/name: {{ include "spark-job.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
SSL Environment Variables
*/}}
{{- define "spark-job.ssl.env" -}}
{{- if .Values.ssl.enabled }}
- name: KEYSTORE_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.ssl.secretName | quote }}
      key: {{ .Values.ssl.keystorePasswordKey | quote }}
- name: TRUSTSTORE_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.ssl.secretName | quote }}
      key: {{ .Values.ssl.truststorePasswordKey | quote }}
- name: KEYSTORE_PATH
  value: "/etc/secrets/spark/{{ .Values.ssl.keystoreFilename }}"
- name: TRUSTSTORE_PATH
  value: "/etc/secrets/spark/{{ .Values.ssl.truststoreFilename }}"
{{- end }}
{{- end }}

{{/*
SSL Volume Mount
*/}}
{{- define "spark-job.ssl.volumeMount" -}}
{{- if .Values.ssl.enabled }}
- name: secrets-vol
  mountPath: /etc/secrets/spark
  readOnly: true
{{- end }}
{{- end }}

{{/*
SSL Volume
*/}}
{{- define "spark-job.ssl.volume" -}}
{{- if .Values.ssl.enabled }}
- name: secrets-vol
  secret:
    secretName: {{ .Values.ssl.secretName | quote }}
{{- end }}
{{- end }}

{{/*
Extra Environment Variables
*/}}
{{- define "spark-job.extraEnv" -}}
{{- range $key, $value := .Values.extraEnv }}
- name: {{ $key }}
  value: {{ $value | quote }}
{{- end }}
{{- end }}
