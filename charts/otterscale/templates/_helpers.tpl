{{- define "otterscale.localPath.provisionerName" -}}
{{- printf "%s/local-path" (include "otterscale.fullname" .) -}}
{{- end -}}

{{- define "otterscale.storageClassName" -}}
{{- if .Values.storage.localPath.enabled -}}
  {{- .Values.storage.localPath.storageClassName -}}
{{- else if .Values.keycloakx.database.persistence.storageClassName -}}
  {{- .Values.keycloakx.database.persistence.storageClassName -}}
{{- end -}}
{{- end -}}

{{- define "otterscale.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

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

{{- define "otterscale.server.fullname" -}}
{{- printf "%s-server" (include "otterscale.fullname" .) -}}
{{- end -}}

{{- define "otterscale.dashboard.fullname" -}}
{{- printf "%s-dashboard" (include "otterscale.fullname" .) -}}
{{- end -}}

{{- define "otterscale.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "otterscale.labels" -}}
helm.sh/chart: {{ include "otterscale.chart" . }}
{{ include "otterscale.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "otterscale.selectorLabels" -}}
app.kubernetes.io/name: {{ include "otterscale.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "otterscale.tls.secretName" -}}
{{- .Values.istio.tls.existingSecret | required "istio.tls.existingSecret must be set when istio.tls.enabled is true" -}}
{{- end -}}

{{- define "otterscale.gatewayRef" -}}
{{- if .Values.istio.gateway.existingGateway -}}
  {{- .Values.istio.gateway.existingGateway -}}
{{- else -}}
  {{- printf "%s-gateway" (include "otterscale.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "otterscale.scheme" -}}
{{- if .Values.istio.tls.enabled -}}https{{- else -}}http{{- end -}}
{{- end -}}

{{- define "otterscale.externalURL" -}}
{{- printf "%s://%s" (include "otterscale.scheme" .) .Values.istio.externalIP -}}
{{- end -}}

{{- define "otterscale.keycloakx.clientSecret" -}}
{{- if not (index .Values "_cachedClientSecret" | default "") -}}
  {{- $secretName := printf "%s-keycloakx-client-secret" (include "otterscale.fullname" .) -}}
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

{{- define "otterscale.valkey.password" -}}
{{- if not (index .Values "_cachedValkeyPassword" | default "") -}}
  {{- $secretName := printf "%s-dashboard-valkey" (include "otterscale.fullname" .) -}}
  {{- $secretKey := "valkey-password" -}}
  {{- $value := "" -}}
  {{- if (index .Values "dashboard-valkey").password -}}
    {{- $value = (index .Values "dashboard-valkey").password -}}
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

{{- define "otterscale.harbor.externalURL" -}}
{{- if .Values.harbor.externalURL -}}
  {{- .Values.harbor.externalURL -}}
{{- else -}}
  {{- include "otterscale.externalURL" . -}}
{{- end -}}
{{- end -}}

{{- define "otterscale.harbor.serviceName" -}}
{{- if eq (toString .Values.harbor.expose.type) "nodePort" -}}
  {{- .Values.harbor.expose.nodePort.name | default "harbor" -}}
{{- else -}}
  {{- .Values.harbor.expose.clusterIP.name | default "harbor" -}}
{{- end -}}
{{- end -}}
