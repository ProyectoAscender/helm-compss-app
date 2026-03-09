{{/*
Expand the name of the chart.
*/}}
{{- define "compss-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "compss-app.fullname" -}}
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
{{- define "compss-app.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "compss-app.labels" -}}
helm.sh/chart: {{ include "compss-app.chart" . }}
{{ include "compss-app.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "compss-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "compss-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "compss-app.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "compss-app.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Build final worker list:
- If .Values.worker.workers exists -> use it, requiring hostname (or name).
- Else generate N workers with name worker-<i>.
Each worker element will have:
  - name (string)  : used in svc/deploy names and labels
  - resources (map): merged with defaults in .Values.worker.resources
  - nodeSelector (optional)
*/}}
{{- define "compss-app.workersFinal" -}}
{{- $root := . -}}
{{- $defaults := dict "resources" ($root.Values.worker.resources | default dict) -}}

{{- if and $root.Values.worker.workers (gt (len $root.Values.worker.workers) 0) -}}
  {{- $out := list -}}
  {{- range $w := $root.Values.worker.workers -}}
    {{- $name := (coalesce $w.hostname $w.name) -}}
    {{- if not $name -}}
      {{- fail "worker.workers[] requires hostname (or name) when provided" -}}
    {{- end -}}
    {{- $merged := mergeOverwrite (deepCopy $defaults) $w -}}
    {{- $_ := set $merged "name" $name -}}
    {{- $out = append $out $merged -}}
  {{- end -}}
{{ toYaml $out }}
{{- else -}}
  {{- $n := int ($root.Values.worker.number | default 1) -}}
  {{- $out := list -}}
  {{- range $i := until $n -}}
    {{- $w := mergeOverwrite (deepCopy $defaults) (dict "name" (printf "worker-%d" $i)) -}}
    {{- $out = append $out $w -}}
  {{- end -}}
{{ toYaml $out }}
{{- end -}}
{{- end }}