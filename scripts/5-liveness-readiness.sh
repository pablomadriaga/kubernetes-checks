#!/usr/bin/env bash
set -uo pipefail
IFS=$'\n\t'

CLUSTER_NAME=$1
TOKEN=$2
CERTIFICATE=$3
IP=$4

#LOG_LEVEL=DEBUG

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

source "$ROOT_DIR/lib/log.sh"
source "$ROOT_DIR/lib/api.sh"
source "$ROOT_DIR/lib/ns.sh"

log_zone "Chequeo cantidad de contenedores sin livenessProbe o readinessProbe"

# Obtener todos los deployments
RESPONSE=$(api_get "$IP" "$TOKEN" "/apis/apps/v1/deployments")

# Chequeo response
if ! echo "$RESPONSE" | jq -e '
  .kind == "DeploymentList" and
  (.items | type == "array")
' >/dev/null; then
  log_error "Respuesta inesperada de API"
  exit 2
fi

# Contar contenedores sin livenessProbe
NO_LIVENESS=$(echo "$RESPONSE" | jq --argjson excludedNamespaces "$NAMESPACES_JSON" '
  [.items[] | select(.metadata.namespace | IN($excludedNamespaces[]) | not)
   | .spec.template.spec.containers[]
   | select(.livenessProbe == null)
  ] | length')

# Contar contenedores sin readinessProbe
NO_READINESS=$(echo "$RESPONSE" | jq --argjson excludedNamespaces "$NAMESPACES_JSON" '
  [.items[] | select(.metadata.namespace | IN($excludedNamespaces[]) | not)
   | .spec.template.spec.containers[]
   | select(.readinessProbe == null)
  ] | length')

# Mostrar resultados con ✔ /✖
if [ "$NO_LIVENESS" -eq 0 ]; then
  log_success "✔ Todos los contenedores tienen livenessProbe - OK"
else
  log_error "✖ Contenedores sin livenessProbe: %s" "$NO_LIVENESS"
fi

if [ "$NO_READINESS" -eq 0 ]; then
  log_success "✔ Todos los contenedores tienen readinessProbe - OK"
else
  log_error "✖ Contenedores sin readinessProbe: %s" "$NO_READINESS"
fi
