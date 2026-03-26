{{/*
Namespace for all resources in this chart.
*/}}
{{- define "rook-ceph-cluster.namespace" -}}
{{ .Release.Namespace }}
{{- end }}
