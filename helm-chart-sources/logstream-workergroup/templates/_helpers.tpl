{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "logstream-workergroup.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "logstream-workergroup.fullname" -}}
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
{{- define "logstream-workergroup.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "logstream-workergroup.labels" -}}
helm.sh/chart: {{ include "logstream-workergroup.chart" . }}
{{ include "logstream-workergroup.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- range $key, $val := .Values.extraLabels }}
{{ $key }}: {{ $val | quote -}}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "logstream-workergroup.selectorLabels" -}}
app.kubernetes.io/name: {{ include "logstream-workergroup.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "logstream-workergroup.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "logstream-workergroup.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Allows for overriding the default RBAC naming scheme
*/}}
{{- define "logstream-workergroup.rbacName" }}
{{- if .Values.rbac.name }}
{{- .Values.rbac.name | quote }}
{{- else }}
{{- printf "%s:%s:%s" (include "logstream-workergroup.fullname" .) "logstream-workergroup" .Release.Namespace | quote }}
{{- end }}
{{- end }}

{{/*
Generated PVC name for the primary shared-storage volume rendered by this
chart when `sharedStorage.claim` is set.
*/}}
{{- define "logstream-workergroup.sharedStorage.claimName" -}}
{{- printf "%s-shared-pq" (include "logstream-workergroup.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Generated PVC name for the legacy shared-storage volume rendered by this
chart when `sharedStorage.legacy.claim` is set.
*/}}
{{- define "logstream-workergroup.sharedStorage.legacyClaimName" -}}
{{- printf "%s-shared-pq-legacy" (include "logstream-workergroup.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Validate a single sharedStorage spec: exactly one of `existingClaim`,
`claim`, or `volume` must be set. Args: dict with `spec` and `name`.
*/}}
{{- define "logstream-workergroup.sharedStorage.validate" -}}
{{- $spec := .spec -}}
{{- $count := 0 -}}
{{- if ne (default "" $spec.existingClaim) "" }}{{- $count = add $count 1 -}}{{- end -}}
{{- if not (empty $spec.claim) }}{{- $count = add $count 1 -}}{{- end -}}
{{- if not (empty $spec.volume) }}{{- $count = add $count 1 -}}{{- end -}}
{{- if ne $count 1 -}}
{{- fail (printf "%s: exactly one of `existingClaim`, `claim`, or `volume` must be set when enabled" .name) -}}
{{- end -}}
{{- end -}}

{{/*
Volume source (yaml fields) for a sharedStorage spec.
Args: dict with `spec` and `claimName` (used when `claim` is set).
*/}}
{{- define "logstream-workergroup.sharedStorage.volumeSource" -}}
{{- $spec := .spec -}}
{{- if ne (default "" $spec.existingClaim) "" }}
persistentVolumeClaim:
  claimName: {{ $spec.existingClaim | quote }}
{{- else if not (empty $spec.claim) }}
persistentVolumeClaim:
  claimName: {{ .claimName | quote }}
{{- else }}
{{- toYaml $spec.volume }}
{{- end -}}
{{- end -}}

{{/*
Render volumeMount entries for shared PQ storage. Caller indents.
*/}}
{{- define "logstream-workergroup.sharedStorage.volumeMounts" -}}
{{- if .Values.sharedStorage.enabled }}
- name: shared-storage
  mountPath: {{ .Values.sharedStorage.mountPath | quote }}
  {{- with .Values.sharedStorage.subPath }}
  subPath: {{ . | quote }}
  {{- end }}
{{- if .Values.sharedStorage.legacy.enabled }}
- name: shared-storage-legacy
  mountPath: {{ .Values.sharedStorage.legacy.mountPath | quote }}
  {{- with .Values.sharedStorage.legacy.subPath }}
  subPath: {{ . | quote }}
  {{- end }}
{{- end }}
{{- end }}
{{- end -}}

{{/*
Render env entries for shared PQ storage. Caller indents.
*/}}
{{- define "logstream-workergroup.sharedStorage.env" -}}
{{- if .Values.sharedStorage.enabled }}
- name: CRIBL_WORKER_VOLUME
  value: {{ .Values.sharedStorage.mountPath | quote }}
{{- if .Values.sharedStorage.legacy.enabled }}
- name: CRIBL_LEGACY_WORKER_VOLUME
  value: {{ .Values.sharedStorage.legacy.mountPath | quote }}
{{- end }}
{{- end }}
{{- end -}}

{{/*
Render volume entries for shared PQ storage. Caller indents.
*/}}
{{- define "logstream-workergroup.sharedStorage.volumes" -}}
{{- if .Values.sharedStorage.enabled }}
{{- include "logstream-workergroup.sharedStorage.validate" (dict "spec" .Values.sharedStorage "name" "sharedStorage") }}
- name: shared-storage
  {{- include "logstream-workergroup.sharedStorage.volumeSource" (dict "spec" .Values.sharedStorage "claimName" (include "logstream-workergroup.sharedStorage.claimName" .)) | nindent 2 }}
{{- if .Values.sharedStorage.legacy.enabled }}
{{- include "logstream-workergroup.sharedStorage.validate" (dict "spec" .Values.sharedStorage.legacy "name" "sharedStorage.legacy") }}
- name: shared-storage-legacy
  {{- include "logstream-workergroup.sharedStorage.volumeSource" (dict "spec" .Values.sharedStorage.legacy "claimName" (include "logstream-workergroup.sharedStorage.legacyClaimName" .)) | nindent 2 }}
{{- end }}
{{- end }}
{{- end -}}