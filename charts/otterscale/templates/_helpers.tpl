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
Return the TLS credential secret name for Istio Gateway
*/}}
{{- define "otterscale.tls.secretName" -}}
{{- if .Values.istio.tls.existingSecret -}}
  {{- .Values.istio.tls.existingSecret -}}
{{- else -}}
  {{- printf "%s-tls-cert" (include "otterscale.fullname" .) -}}
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
      {{- $value = randAlphaNum 10 -}}
    {{- end -}}
  {{- end -}}
  {{- $_ := set .Values "_cachedValkeyPassword" $value -}}
{{- end -}}
{{- index .Values "_cachedValkeyPassword" -}}
{{- end -}}

{{/*
Harbor external URL (same as OtterScale base URL — Harbor adds /harbor/ internally)
*/}}
{{- define "otterscale.harbor.externalURL" -}}
{{- if .Values.harbor.externalURL -}}
  {{- .Values.harbor.externalURL -}}
{{- else -}}
  {{- include "otterscale.externalURL" . -}}
{{- end -}}
{{- end -}}

{{/*
Harbor ClusterIP service name (matches expose.clusterIP.name in Harbor chart)
*/}}
{{- define "otterscale.harbor.serviceName" -}}
{{- .Values.harbor.expose.clusterIP.name | default "harbor" -}}
{{- end -}}
