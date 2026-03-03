#!/usr/bin/env bash
set -uo pipefail
IFS=$'\n\t'

CLUSTER_NAME=$1
TOKEN=$2
CERTIFICATE=$3
IP=$4

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

source "$ROOT_DIR/lib/log.sh"
source "$ROOT_DIR/lib/api.sh"
source "$ROOT_DIR/lib/ns.sh"

log_zone "Chequeo cantidad de contenedores sin Requests y Limits"

RESPONSE=$(api_get "$IP" "$TOKEN" "/apis/apps/v1/deployments")

if [ $? -ne 0 ] || [ -z "$RESPONSE" ]; then
  log_error "Error: Falló la solicitud a la API de deployments."
  exit 1
fi

RESULTS=$(echo "$RESPONSE" | jq --argjson excludedNamespaces "$NAMESPACES_JSON" '
  [
    .items[]
    | select(.metadata.namespace | IN($excludedNamespaces[]) | not)
    | .spec.template.spec.containers[]
  ]
  | reduce .[] as $c (
      {
        no_req_cpu: 0,
        no_req_mem: 0,
        no_limit_cpu: 0,
        no_limit_mem: 0
      };
      .no_req_cpu   += (if $c.resources.requests.cpu     == null then 1 else 0 end) |
      .no_req_mem   += (if $c.resources.requests.memory  == null then 1 else 0 end) |
      .no_limit_cpu += (if $c.resources.limits.cpu       == null then 1 else 0 end) |
      .no_limit_mem += (if $c.resources.limits.memory    == null then 1 else 0 end)
    )
')

NO_REQ_CPU=$(jq -r '.no_req_cpu' <<< "$RESULTS")
NO_REQ_MEM=$(jq -r '.no_req_mem' <<< "$RESULTS")
NO_LIMIT_CPU=$(jq -r '.no_limit_cpu' <<< "$RESULTS")
NO_LIMIT_MEM=$(jq -r '.no_limit_mem' <<< "$RESULTS")

if [ "$NO_REQ_CPU" -eq 0 ]; then
  log_success "✔ Todos los contenedores tienen Requests CPU - OK"
else
  log_error "✖ Contenedores sin Requests CPU: %s" "$NO_REQ_CPU"
fi

if [ "$NO_LIMIT_CPU" -eq 0 ]; then
  log_success "✔ Todos los contenedores tienen Limits CPU - OK"
else
  log_error "✖ Contenedores sin Limits CPU: %s" "$NO_LIMIT_CPU"
fi

if [ "$NO_REQ_MEM" -eq 0 ]; then
  log_success "✔ Todos los contenedores tienen Requests Memoria - OK"
else
  log_error "✖ Contenedores sin Requests Memoria: %s" "$NO_REQ_MEM"
fi

if [ "$NO_LIMIT_MEM" -eq 0 ]; then
  log_success "✔ Todos los contenedores tienen Limits Memoria - OK"
else
  log_error "✖ Contenedores sin Limits Memoria: %s" "$NO_LIMIT_MEM"
fi
