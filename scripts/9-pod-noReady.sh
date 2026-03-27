#!/usr/bin/env bash
set -uo pipefail
IFS=$'\n\t'

CLUSTER_NAME=$1
TOKEN=$2
CERTIFICATE=$3
IP=$4
ENV=$5

WIDTH=$(tput cols)
MAX_NS=$((WIDTH / 3))

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

source "$ROOT_DIR/lib/log.sh"
source "$ROOT_DIR/lib/api.sh"
source "$ROOT_DIR/lib/ns.sh"

log_zone "Chequeo de pods NoReady"

RAW=$(api_get "$IP" "$TOKEN" "/api/v1/pods")

if [ -z "$RAW" ]; then
  log_error "Error obteniendo pods"
  exit 1
fi

PROBLEMS=$(echo "$RAW" | jq --argjson excludedNamespaces "$NAMESPACES_JSON" '
  .items // []
  | map(
      ( .status.conditions // [] 
        | map(select(.type=="Ready")) 
        | .[0]?.status ) as $ready
      |
      select(
        (
          .status.phase == "Running" and $ready == "True"
        )
        or
        .status.phase == "Succeeded"
        | not
      )
      |
      select(.metadata.namespace | IN($excludedNamespaces[]) | not)
      |
      {
        namespace: .metadata.namespace,
        name: .metadata.name,
        phase: .status.phase
      }
    )
')

if [ "$(echo "$PROBLEMS" | jq 'length')" -eq 0 ]; then
  log_success "✔ Todos los pods están OK"
  exit 0
fi

TABLE=$(
  printf "%-${MAX_NS}s %s\n" "  NAMESPACE" "PROBLEM_PODS"

  echo "$PROBLEMS" | jq -r '
    group_by(.namespace)
    | map({namespace: .[0].namespace, problem_pods: length})
    | .[]
    | "\(.namespace)\t\(.problem_pods)"
  ' | awk -F'\t' -v maxns="$MAX_NS" '{
      ns=$1;
      if(length(ns)>maxns) ns=substr(ns,1,maxns-3)"...";
      printf "  %-*s %s\n", maxns, ns, $2
  }'
)

log_error "Pods NoReady detectados"
printf "%b%s%b" "$COLOR_ERROR" "$TABLE" "$COLOR_RESET"
