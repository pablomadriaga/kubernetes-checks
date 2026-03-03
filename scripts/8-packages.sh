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

log_zone "Analizando Packages"
check_packages_status() {

  RESPONSE=$(api_get "$IP" "$TOKEN" "/apis/kappctrl.k14s.io/v1alpha1/apps")

  # Filtrar apps que tengan error en ReconcileSucceeded, exitCode o finished
  ERRORS=$(echo "$RESPONSE" | jq -r '[.items[]
    | {
        namespace: .metadata.namespace,
        name: .metadata.name,
        reconcileSucceeded: (.status.conditions[]? | select(.type=="ReconcileSucceeded") | .status // "False"),
        exitCode: (.status.deploy.exitCode // 1),
        finished: (.status.deploy.finished // false)
      }
    | select(.reconcileSucceeded != "True" or .exitCode != 0 or .finished != true)
  ]')

  ERRORS_COUNT=$(echo "$ERRORS" | jq 'length')

  if [ "$ERRORS_COUNT" -eq 0 ]; then
    log_success "✔ Todos los Packages están OK"
  else
    log_error "✖ Packages con error: %s" "$ERRORS_COUNT"
    log_error "Nombres de Packages con error:"
    echo "$ERRORS" | jq -r '.[] | "    \(.namespace)/\(.name)"'
    exit 1
  fi
}

check_packages_status

