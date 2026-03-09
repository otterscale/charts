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
Crane container image (debug tag includes busybox for cp).
*/}}
{{- define "aidaptivcache-finetune.craneImage" -}}
{{- $output := .Values.outputImage | default dict -}}
{{- $crane := (get $output "crane") | default dict -}}
{{- (get $crane "image") | default "gcr.io/go-containerregistry/crane:debug" -}}
{{- end }}

{{/*
Default base image for crane append operation.
*/}}
{{- define "aidaptivcache-finetune.craneBaseImage" -}}
{{- $output := .Values.outputImage | default dict -}}
{{- $crane := (get $output "crane") | default dict -}}
{{- (get $crane "baseImage") | default "busybox:latest" -}}
{{- end }}

{{/*
Path to the crane binary inside the main container.
*/}}
{{- define "aidaptivcache-finetune.craneBin" -}}
/crane-bin/crane
{{- end }}

{{/*
Init-container image providing the kit CLI.
*/}}
{{- define "aidaptivcache-finetune.kitopsImage" -}}
{{- $output := .Values.outputImage | default dict -}}
{{- $kitops := (get $output "kitops") | default dict -}}
{{- (get $kitops "image") | default "ghcr.io/kitops-ml/kitops:v1.11.0" -}}
{{- end }}

{{/*
Path to the kit binary inside the main container.
*/}}
{{- define "aidaptivcache-finetune.kitopsBin" -}}
/kitops-bin/kit
{{- end }}
