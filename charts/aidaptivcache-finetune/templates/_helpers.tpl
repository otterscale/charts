{{/*
Expand the name of the chart.
*/}}
{{- define "aidaptivcache-finetune.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "aidaptivcache-finetune.fullname" -}}
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
{{- define "aidaptivcache-finetune.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "aidaptivcache-finetune.labels" -}}
helm.sh/chart: {{ include "aidaptivcache-finetune.chart" . }}
{{ include "aidaptivcache-finetune.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "aidaptivcache-finetune.selectorLabels" -}}
app.kubernetes.io/name: {{ include "aidaptivcache-finetune.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Crane OCI image reference.
  imageVolume  → distroless (latest)
  initContainer → debug (includes busybox for cp)
*/}}
{{- define "aidaptivcache-finetune.craneImage" -}}
{{- if .Values.outputImage.crane.image -}}
  {{- .Values.outputImage.crane.image -}}
{{- else if .Values.outputImage.crane.useImageVolume -}}
  gcr.io/go-containerregistry/crane:latest
{{- else -}}
  gcr.io/go-containerregistry/crane:debug
{{- end -}}
{{- end }}

{{/*
Path to the crane binary inside the main container.
*/}}
{{- define "aidaptivcache-finetune.craneBin" -}}
{{- if .Values.outputImage.crane.useImageVolume -}}
/opt/crane/ko-app/crane
{{- else -}}
/crane-bin/crane
{{- end -}}
{{- end }}
