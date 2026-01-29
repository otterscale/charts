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
app.kubernetes.io/version: {{ .Chart.AppVersion }}
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
Get or generate Keycloak client secret (32 characters)
Caches the value to ensure consistency across all template usages
*/}}
{{- define "otterscale.keycloak.clientSecret" -}}
{{- if not .Values._generatedClientSecret -}}
  {{- $secretName := printf "%s-keycloak-client-secret" (include "otterscale.fullname" .) -}}
  {{- $existingSecret := lookup "v1" "Secret" .Release.Namespace $secretName -}}
  {{- if $existingSecret -}}
    {{/* Use existing secret value during upgrades */}}
    {{- $_ := set .Values "_generatedClientSecret" (index $existingSecret.data "client-secret" | b64dec) -}}
  {{- else if .Values.keycloakx.client.secret -}}
    {{/* Use user-provided value */}}
    {{- $_ := set .Values "_generatedClientSecret" .Values.keycloakx.client.secret -}}
  {{- else -}}
    {{/* Generate new random 32-character secret for first installation */}}
    {{- $_ := set .Values "_generatedClientSecret" (randAlphaNum 32) -}}
  {{- end -}}
{{- end -}}
{{- .Values._generatedClientSecret -}}
{{- end }}

{{/*
Get or generate Postgres database password (10 characters)
Caches the value to ensure consistency across all template usages
*/}}
{{- define "otterscale.postgres.password" -}}
{{- if not .Values._generatedPostgresPassword -}}
  {{- $secretName := .Values.keycloakx.database.existingSecret -}}
  {{- $existingSecret := lookup "v1" "Secret" .Release.Namespace $secretName -}}
  {{- if $existingSecret -}}
    {{/* Use existing secret value during upgrades */}}
    {{- $_ := set .Values "_generatedPostgresPassword" (index $existingSecret.data "postgres-password" | b64dec) -}}
  {{- else if .Values.keycloakx.database.password -}}
    {{/* Use user-provided value */}}
    {{- $_ := set .Values "_generatedPostgresPassword" .Values.keycloakx.database.password -}}
  {{- else -}}
    {{/* Generate new random 10-character password for first installation */}}
    {{- $_ := set .Values "_generatedPostgresPassword" (randAlphaNum 10) -}}
  {{- end -}}
{{- end -}}
{{- .Values._generatedPostgresPassword -}}
{{- end }}

{{/*
Get or generate Valkey password (10 characters)
Caches the value to ensure consistency across all template usages
*/}}
{{- define "otterscale.valkey.password" -}}
{{- if not .Values._generatedValkeyPassword -}}
  {{- $secretName := printf "%s-valkey" (include "otterscale.fullname" .) -}}
  {{- $existingSecret := lookup "v1" "Secret" .Release.Namespace $secretName -}}
  {{- if $existingSecret -}}
    {{/* Use existing secret value during upgrades */}}
    {{- $_ := set .Values "_generatedValkeyPassword" (index $existingSecret.data "valkey-password" | b64dec) -}}
  {{- else if .Values.valkey.aclUsers.default.password -}}
    {{/* Use user-provided value */}}
    {{- $_ := set .Values "_generatedValkeyPassword" .Values.valkey.aclUsers.default.password -}}
  {{- else -}}
    {{/* Generate new random 10-character password for first installation */}}
    {{- $_ := set .Values "_generatedValkeyPassword" (randAlphaNum 10) -}}
  {{- end -}}
{{- end -}}
{{- .Values._generatedValkeyPassword -}}
{{- end }}
