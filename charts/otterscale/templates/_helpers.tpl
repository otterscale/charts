{{/*
Namespace for all resources.
Prefer .Values.namespace; fall back to .Release.Namespace.
*/}}
{{- define "otterscale.namespace" -}}
{{- .Values.namespace | default .Release.Namespace -}}
{{- end -}}

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

{{- define "otterscale.tunnel.fullname" -}}
{{- printf "%s-server-tunnel" (include "otterscale.fullname" .) -}}
{{- end -}}

{{- define "otterscale.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "otterscale.labels" -}}
helm.sh/chart: {{ include "otterscale.chart" . }}
{{ include "otterscale.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "otterscale.selectorLabels" -}}
app.kubernetes.io/name: {{ include "otterscale.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Name of the TLS Secret the Gateway HTTPS listener references.
  - crt + key set     : a kubernetes.io/tls Secret this chart creates.
  - existingSecret set : a Secret the user created out-of-band (in the Gateway ns).
*/}}
{{- define "otterscale.tls.secretName" -}}
{{- if and .Values.envoy.tls.crt .Values.envoy.tls.key -}}
  {{- printf "%s-tls" (include "otterscale.fullname" .) -}}
{{- else if .Values.envoy.tls.existingSecret -}}
  {{- .Values.envoy.tls.existingSecret -}}
{{- else -}}
  {{- required "envoy.tls: set crt+key (chart creates the Secret) or existingSecret when envoy.tls.enabled is true" "" -}}
{{- end -}}
{{- end }}

{{- define "otterscale.gatewayRef" -}}
{{- .Values.envoy.gateway.name | required "envoy.gateway.name must be set when envoy is enabled" -}}
{{- end -}}

{{/*
Namespace the Gateway, EnvoyProxy and the chart-managed TLS Secret/Certificate
live in (default: envoy-gateway-system). HTTPRoutes stay in the release
namespace and attach cross-namespace, so the Gateway listeners use
allowedRoutes.from: All. Co-locating the TLS Secret with the Gateway avoids
needing a ReferenceGrant for the HTTPS listener's certificateRef.
*/}}
{{- define "otterscale.gateway.namespace" -}}
{{- .Values.envoy.gateway.namespace | default (include "otterscale.namespace" .) -}}
{{- end -}}

{{/*
Gateway listener sectionName an HTTPRoute should attach to.
HTTPS when TLS is enabled, otherwise HTTP.
*/}}
{{- define "otterscale.gateway.sectionName" -}}
{{- if .Values.envoy.tls.enabled -}}https{{- else -}}http{{- end -}}
{{- end -}}

{{/*
External host for the OtterScale dashboard (scheme + port stripped).
*/}}
{{- define "otterscale.harbor.host" -}}
{{- (splitList "://" .Values.harbor.externalURL) | last | trimSuffix "/" | splitList ":" | first -}}
{{- end -}}

{{/*
Base external URL (value of .Values.dashboard.externalURL with trailing slash stripped).
*/}}
{{- define "otterscale.externalURL" -}}
{{- .Values.dashboard.externalURL | trimSuffix "/" -}}
{{- end -}}

{{/*
Extract scheme from externalURL (e.g. "https://example.com" → "https").
*/}}
{{- define "otterscale.scheme" -}}
{{- (splitList "://" .Values.dashboard.externalURL) | first -}}
{{- end -}}

{{/*
Extract host from externalURL (e.g. "https://example.com" → "example.com").
*/}}
{{- define "otterscale.host" -}}
{{- (splitList "://" .Values.dashboard.externalURL) | last | trimSuffix "/" -}}
{{- end -}}

{{/*
Server external URL advertised to clients.
Priority: server.externalURL > auto-derive from nodePort > externalURL.
*/}}
{{- define "otterscale.server.externalURL" -}}
{{- if .Values.server.externalURL -}}
  {{- .Values.server.externalURL -}}
{{- else if .Values.server.service.nodePort -}}
  {{- printf "%s://%s:%v" (include "otterscale.scheme" .) (include "otterscale.host" .) .Values.server.service.nodePort -}}
{{- else -}}
  {{- include "otterscale.externalURL" . -}}
{{- end -}}
{{- end -}}

{{/*
Server external tunnel URL advertised to agents.
Priority: server.externalTunnelURL > auto-derive from nodePort > externalURL.
*/}}
{{- define "otterscale.server.externalTunnelURL" -}}
{{- if .Values.server.externalTunnelURL -}}
  {{- .Values.server.externalTunnelURL -}}
{{- else if .Values.server.tunnelService.nodePort -}}
  {{- printf "%s://%s:%v" (include "otterscale.scheme" .) (include "otterscale.host" .) .Values.server.tunnelService.nodePort -}}
{{- else -}}
  {{- include "otterscale.externalURL" . -}}
{{- end -}}
{{- end -}}

{{/*
Keycloak realm URL (external-facing).
Combines externalURL + relativePath + realms/<realm>.
*/}}
{{- define "otterscale.keycloakx.realmURL" -}}
{{- $relativePath := .Values.keycloakx.http.relativePath | trimSuffix "/" -}}
{{- printf "%s%s/realms/%s" (include "otterscale.externalURL" .) $relativePath .Values.keycloakx.realm -}}
{{- end -}}

{{/*
Keycloak fullname: release-name + nameOverride (or "keycloakx" if unset).
*/}}
{{- define "otterscale.keycloakx.fullname" -}}
{{- printf "%s-%s" .Release.Name (default "keycloakx" .Values.keycloakx.nameOverride) -}}
{{- end -}}

{{/*
Keycloak internal service FQDN.
*/}}
{{- define "otterscale.keycloakx.serviceName" -}}
{{- printf "%s-http" (include "otterscale.keycloakx.fullname" .) -}}
{{- end -}}

{{- define "otterscale.keycloakx.dashboardClientSecret" -}}
{{- if not (index .Values "_cachedDashboardClientSecret" | default "") -}}
  {{- $secretName := printf "%s-dashboard-client-secret" (include "otterscale.keycloakx.fullname" .) -}}
  {{- $secretKey := "client-secret" -}}
  {{- $value := "" -}}
  {{- if .Values.keycloakx.clients.dashboard.secret -}}
    {{- $value = .Values.keycloakx.clients.dashboard.secret -}}
  {{- else -}}
    {{- $existingSecret := (lookup "v1" "Secret" (include "otterscale.namespace" .) $secretName) -}}
    {{- if and $existingSecret (hasKey $existingSecret.data $secretKey) -}}
      {{- $value = index $existingSecret.data $secretKey | b64dec -}}
    {{- else -}}
      {{- $value = randAlphaNum 32 -}}
    {{- end -}}
  {{- end -}}
  {{- $_ := set .Values "_cachedDashboardClientSecret" $value -}}
{{- end -}}
{{- index .Values "_cachedDashboardClientSecret" -}}
{{- end -}}

{{- define "otterscale.keycloakx.harborClientSecret" -}}
{{- if not (index .Values "_cachedHarborClientSecret" | default "") -}}
  {{- $secretName := printf "%s-harbor-client-secret" (include "otterscale.keycloakx.fullname" .) -}}
  {{- $secretKey := "client-secret" -}}
  {{- $value := "" -}}
  {{- if .Values.keycloakx.clients.harbor.secret -}}
    {{- $value = .Values.keycloakx.clients.harbor.secret -}}
  {{- else -}}
    {{- $existingSecret := (lookup "v1" "Secret" (include "otterscale.namespace" .) $secretName) -}}
    {{- if and $existingSecret (hasKey $existingSecret.data $secretKey) -}}
      {{- $value = index $existingSecret.data $secretKey | b64dec -}}
    {{- else -}}
      {{- $value = randAlphaNum 32 -}}
    {{- end -}}
  {{- end -}}
  {{- $_ := set .Values "_cachedHarborClientSecret" $value -}}
{{- end -}}
{{- index .Values "_cachedHarborClientSecret" -}}
{{- end -}}

{{- define "otterscale.valkey.password" -}}
{{- if not (index .Values "_cachedValkeyPassword" | default "") -}}
  {{- $secretName := printf "%s-dashboard-valkey" (include "otterscale.fullname" .) -}}
  {{- $secretKey := "valkey-password" -}}
  {{- $value := "" -}}
  {{- if (index .Values "dashboard-valkey").password -}}
    {{- $value = (index .Values "dashboard-valkey").password -}}
  {{- else -}}
    {{- $existingSecret := (lookup "v1" "Secret" (include "otterscale.namespace" .) $secretName) -}}
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

{{- define "otterscale.harbor.serviceName" -}}
{{- if eq (toString .Values.harbor.expose.type) "nodePort" -}}
  {{- .Values.harbor.expose.nodePort.name | default "harbor" -}}
{{- else -}}
  {{- .Values.harbor.expose.clusterIP.name | default "harbor" -}}
{{- end -}}
{{- end -}}

{{/*
Harbor service port (HTTP).
*/}}
{{- define "otterscale.harbor.servicePort" -}}
{{- if eq (toString .Values.harbor.expose.type) "nodePort" -}}
  {{- .Values.harbor.expose.nodePort.ports.http.port | default 80 -}}
{{- else -}}
  {{- .Values.harbor.expose.clusterIP.ports.httpPort | default 80 -}}
{{- end -}}
{{- end -}}

{{/*
Component-scoped labels for server.
*/}}
{{- define "otterscale.server.labels" -}}
{{ include "otterscale.labels" . }}
app.kubernetes.io/component: backend
{{- end -}}

{{/*
Component-scoped selector labels for server.
*/}}
{{- define "otterscale.server.selectorLabels" -}}
{{ include "otterscale.selectorLabels" . }}
app.kubernetes.io/component: backend
{{- end -}}

{{/*
Component-scoped labels for dashboard.
*/}}
{{- define "otterscale.dashboard.labels" -}}
{{ include "otterscale.labels" . }}
app.kubernetes.io/component: frontend
{{- end -}}

{{/*
Component-scoped selector labels for dashboard.
*/}}
{{- define "otterscale.dashboard.selectorLabels" -}}
{{ include "otterscale.selectorLabels" . }}
app.kubernetes.io/component: frontend
{{- end -}}

{{/*
Server ServiceAccount name.
*/}}
{{- define "otterscale.server.serviceAccountName" -}}
{{- if .Values.server.serviceAccount.create -}}
  {{- default (include "otterscale.server.fullname" .) .Values.server.serviceAccount.name -}}
{{- else -}}
  {{- default "default" .Values.server.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{/*
Dashboard ServiceAccount name.
*/}}
{{- define "otterscale.dashboard.serviceAccountName" -}}
{{- if .Values.dashboard.serviceAccount.create -}}
  {{- default (include "otterscale.dashboard.fullname" .) .Values.dashboard.serviceAccount.name -}}
{{- else -}}
  {{- default "default" .Values.dashboard.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{/*
Render image reference with global registry override support.
Usage: {{ include "otterscale.image" (dict "imageRoot" .Values.server.image "global" .Values.global "chart" .Chart) }}
*/}}
{{- define "otterscale.image" -}}
{{- $registry := "" -}}
{{- if and .global .global.imageRegistry -}}
  {{- $registry = .global.imageRegistry -}}
{{- end -}}
{{- $repository := .imageRoot.repository -}}
{{- $tag := required "image.tag is required" .imageRoot.tag -}}
{{- if $registry -}}
  {{- printf "%s/%s:%s" $registry $repository $tag -}}
{{- else -}}
  {{- printf "%s:%s" $repository $tag -}}
{{- end -}}
{{- end -}}

{{/*
Render the dashboard image reference.
When ee.enabled is true, the repository is switched to its "-ee" variant
(e.g. ghcr.io/otterscale/dashboard → ghcr.io/otterscale/dashboard-ee).
*/}}
{{- define "otterscale.dashboard.image" -}}
{{- $imageRoot := deepCopy .Values.dashboard.image -}}
{{- if .Values.ee.enabled -}}
  {{- $_ := set $imageRoot "repository" (printf "%s-ee" $imageRoot.repository) -}}
{{- end -}}
{{- include "otterscale.image" (dict "imageRoot" $imageRoot "global" .Values.global "chart" .Chart) -}}
{{- end -}}
