{{/*
Return the internal provisioner name used by the local-path StorageClass
and the provisioner Deployment --provisioner-name flag.
Formatted as "<fullname>/local-path" to be unique per release.
*/}}
{{- define "otterscale.localPath.provisionerName" -}}
{{- printf "%s/local-path" (include "otterscale.fullname" .) -}}
{{- end -}}

{{/*
Return the effective StorageClass name for PVCs managed by this chart.
Priority:
  1. storage.localPath.enabled → use the chart's own StorageClass
  2. keycloakx.database.persistence.storageClassName (explicit override)
  3. "" → let Kubernetes use the cluster default StorageClass
*/}}
{{- define "otterscale.storageClassName" -}}
{{- if .Values.storage.localPath.enabled -}}
  {{- .Values.storage.localPath.storageClassName -}}
{{- else if .Values.keycloakx.database.persistence.storageClassName -}}
  {{- .Values.keycloakx.database.persistence.storageClassName -}}
{{- end -}}
{{- end -}}

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
Fully qualified name for the API (backend) component.
*/}}
{{- define "otterscale.api.fullname" -}}
{{- printf "%s-api" (include "otterscale.fullname" .) -}}
{{- end -}}

{{/*
Fully qualified name for the Dashboard (frontend) component.
*/}}
{{- define "otterscale.dashboard.fullname" -}}
{{- printf "%s-dashboard" (include "otterscale.fullname" .) -}}
{{- end -}}

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
Return the TLS credential secret name for Istio Gateway.
Requires istio.tls.existingSecret to be set.
*/}}
{{- define "otterscale.tls.secretName" -}}
{{- .Values.istio.tls.existingSecret | required "istio.tls.existingSecret must be set when istio.tls.enabled is true" -}}
{{- end -}}

{{/*
Return the gateway reference for VirtualService.
Uses existingGateway if set, otherwise uses the chart-managed gateway name.
*/}}
{{- define "otterscale.gatewayRef" -}}
{{- if .Values.istio.gateway.existingGateway -}}
  {{- .Values.istio.gateway.existingGateway -}}
{{- else -}}
  {{- printf "%s-gateway" (include "otterscale.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Return the URL scheme (http or https) based on TLS setting
*/}}
{{- define "otterscale.scheme" -}}
{{- if .Values.istio.tls.enabled -}}https{{- else -}}http{{- end -}}
{{- end -}}

{{/*
Return the external base URL (scheme + externalIP)
*/}}
{{- define "otterscale.externalURL" -}}
{{- printf "%s://%s" (include "otterscale.scheme" .) .Values.istio.externalIP -}}
{{- end -}}

{{/*
Get or generate Keycloak client secret (32 characters)
Caches the value in .Values._cache to ensure consistency across all templates
*/}}
{{- define "otterscale.keycloak.clientSecret" -}}
{{- if not (index .Values "_cachedClientSecret" | default "") -}}
  {{- $secretName := printf "%s-keycloak-client-secret" (include "otterscale.fullname" .) -}}
  {{- $secretKey := "client-secret" -}}
  {{- $value := "" -}}
  {{- if .Values.keycloakx.client.secret -}}
    {{- $value = .Values.keycloakx.client.secret -}}
  {{- else -}}
    {{- $existingSecret := (lookup "v1" "Secret" .Release.Namespace $secretName) -}}
    {{- if and $existingSecret (hasKey $existingSecret.data $secretKey) -}}
      {{- $value = index $existingSecret.data $secretKey | b64dec -}}
    {{- else -}}
      {{- $value = randAlphaNum 32 -}}
    {{- end -}}
  {{- end -}}
  {{- $_ := set .Values "_cachedClientSecret" $value -}}
{{- end -}}
{{- index .Values "_cachedClientSecret" -}}
{{- end -}}

{{/*
Get or generate Valkey password
Caches the value in .Values._cache to ensure consistency across all templates
*/}}
{{- define "otterscale.valkey.password" -}}
{{- if not (index .Values "_cachedValkeyPassword" | default "") -}}
  {{- $secretName := printf "%s-valkey" (include "otterscale.fullname" .) -}}
  {{- $secretKey := "valkey-password" -}}
  {{- $value := "" -}}
  {{- if .Values.valkey.password -}}
    {{- $value = .Values.valkey.password -}}
  {{- else -}}
    {{- $existingSecret := (lookup "v1" "Secret" .Release.Namespace $secretName) -}}
    {{- if and $existingSecret (hasKey $existingSecret.data $secretKey) -}}
      {{- $value = index $existingSecret.data $secretKey | b64dec -}}
    {{- else -}}
      {{- $value = randAlphaNum 24 -}}
    {{- end -}}
  {{- end -}}
  {{- $_ := set .Values "_cachedValkeyPassword" $value -}}
{{- end -}}
{{- index .Values "_cachedValkeyPassword" -}}
{{- end -}}

{{/*
Harbor external URL (same as OtterScale base URL)
*/}}
{{- define "otterscale.harbor.externalURL" -}}
{{- if .Values.harbor.externalURL -}}
  {{- .Values.harbor.externalURL -}}
{{- else -}}
  {{- include "otterscale.externalURL" . -}}
{{- end -}}
{{- end -}}

{{/*
Harbor ClusterIP / NodePort service name (matches expose.*.name in Harbor chart)
*/}}
{{- define "otterscale.harbor.serviceName" -}}
{{- if eq (toString .Values.harbor.expose.type) "nodePort" -}}
  {{- .Values.harbor.expose.nodePort.name | default "harbor" -}}
{{- else -}}
  {{- .Values.harbor.expose.clusterIP.name | default "harbor" -}}
{{- end -}}
{{- end -}}
