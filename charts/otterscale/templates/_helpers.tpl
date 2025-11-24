{{/*
Expand the name of the chart.
*/}}
{{- define "otterscale.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "otterscale.fullname" -}}
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
{{- define "otterscale.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "otterscale.labels" -}}
helm.sh/chart: {{ include "otterscale.chart" . }}
{{ include "otterscale.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "otterscale.selectorLabels" -}}
app.kubernetes.io/name: {{ include "otterscale.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "otterscale.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "otterscale.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Get image pull policy from component or global
*/}}
{{- define "otterscale.imagePullPolicy" -}}
{{- .pullPolicy | default .global.imagePullPolicy | default "IfNotPresent" }}
{{- end }}

{{/*
Generate full image name
Usage: include "otterscale.image" (dict "image" .Values.otterscale.image "defaultTag" .Values.appVersion)
*/}}
{{- define "otterscale.image" -}}
{{- $tag := .image.tag | default .defaultTag | default "latest" }}
{{- printf "%s:%s" .image.repository $tag }}
{{- end }}



{{/*
Get podAnnotations from component or global
*/}}
{{- define "otterscale.podAnnotations" -}}
{{- $annotations := .component.podAnnotations | default .global.podAnnotations | default dict }}
{{- if $annotations }}
{{- toYaml $annotations }}
{{- end }}
{{- end }}

{{/*
Get nodeSelector from component or global
*/}}
{{- define "otterscale.nodeSelector" -}}
{{- $nodeSelector := .component.nodeSelector | default .global.nodeSelector | default dict }}
{{- if $nodeSelector }}
{{- toYaml $nodeSelector }}
{{- end }}
{{- end }}

{{/*
Get tolerations from component or global
*/}}
{{- define "otterscale.tolerations" -}}
{{- $tolerations := .component.tolerations | default .global.tolerations | default list }}
{{- if $tolerations }}
{{- toYaml $tolerations }}
{{- end }}
{{- end }}

{{/*
Get affinity from component or global
*/}}
{{- define "otterscale.affinity" -}}
{{- $affinity := .component.affinity | default .global.affinity | default dict }}
{{- if $affinity }}
{{- toYaml $affinity }}
{{- end }}
{{- end }}



{{/*
PostgreSQL wait initContainer
*/}}
{{- define "otterscale.postgresql.waitInitContainer" -}}
- name: wait-for-postgres
  image: postgres:15-alpine
  command:
    - sh
    - -c
    - |
      until pg_isready -h {{ .Release.Name }}-postgresql -p 5432 -U {{ .Values.postgresql.auth.username }}; do
        echo "Waiting for PostgreSQL to be ready..."
        sleep 2
      done
      echo "PostgreSQL is ready!"
  env:
    - name: PGPASSWORD
      value: {{ .Values.postgresql.auth.postgresPassword | quote }}
{{- end }}

{{/*
Validate required values
*/}}
{{- define "otterscale.validateValues" -}}
{{- if and .Values.postgresql.enabled (not .Values.postgresql.auth.password) }}
{{- fail "PostgreSQL password is required when PostgreSQL is enabled. Please set postgresql.auth.password" }}
{{- end }}
{{- if and .Values.keycloak.enabled (not .Values.keycloak.auth.adminPassword) }}
{{- fail "Keycloak admin password is required when Keycloak is enabled. Please set keycloak.auth.adminPassword" }}
{{- end }}
{{- end }}
