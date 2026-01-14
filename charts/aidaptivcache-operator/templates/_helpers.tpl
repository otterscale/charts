{{/*
Expand the name of the chart.
*/}}
{{- define "aidaptivcache-operator.name" -}}
{{- default .Chart.Name .Values.operator.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "aidaptivcache-operator.fullname" -}}
{{- if .Values.operator.fullnameOverride }}
{{- .Values.operator.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.operator.nameOverride }}
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
{{- define "aidaptivcache-operator.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "aidaptivcache-operator.labels" -}}
helm.sh/chart: {{ include "aidaptivcache-operator.chart" . }}
{{ include "aidaptivcache-operator.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "aidaptivcache-operator.selectorLabels" -}}
app.kubernetes.io/name: {{ include "aidaptivcache-operator.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "aidaptivcache-operator.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "aidaptivcache-operator.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- /*
Service port for nvme exporter
*/ -}}
{{- define "aidaptivcache.handshakePort" -}}
{{- $ports := .Values.service.ports | default list -}}
{{- $p := "" -}}
{{- range $i, $item := $ports -}}
  {{- if and $item (eq $item.name "handshake") -}}
    {{- $p = printf "%v" $item.port -}}
  {{- end -}}
{{- end -}}
{{- if eq $p "" -}}
  {{- fail "values.service.ports does not contain a port named 'handshake'" -}}
{{- end -}}
{{- printf "%s" $p -}}
{{- end -}}
