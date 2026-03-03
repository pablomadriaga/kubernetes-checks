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

log_zone "Chequeo pods en nodos del control plane"

check_control_plane_pods() {

  # 1️⃣ Obtener todos los nodos
  RESPONSE_NODES=$(api_get "$IP" "$TOKEN" "/api/v1/nodes")

  if [ -z "$RESPONSE_NODES" ]; then
    log_error "Error obteniendo nodos"
    return 1
  fi

  # 2️⃣ Obtener nombres de nodos control-plane
  CONTROL_PLANE_JSON=$(echo "$RESPONSE_NODES" | jq '
    [
      .items[]
      | select(.spec.taints[]?.key=="node-role.kubernetes.io/control-plane")
      | .metadata.name
    ]
  ')

  CONTROL_PLANE_COUNT=$(jq 'length' <<< "$CONTROL_PLANE_JSON")

  if [ "$CONTROL_PLANE_COUNT" -eq 0 ]; then
    log_warning "No se encontraron nodos control plane."
    return
  fi

  # 3️⃣ Obtener todos los pods UNA sola vez
  RESPONSE_PODS=$(api_get "$IP" "$TOKEN" "/api/v1/pods")

  if [ -z "$RESPONSE_PODS" ]; then
    log_error "Error obteniendo pods"
    return 1
  fi

  # 4️⃣ Procesar todo en memoria
  RESULTS=$(jq \
    --argjson controlPlanes "$CONTROL_PLANE_JSON" \
    --argjson excludedNamespaces "$NAMESPACES_JSON" '
    # Filtrar solo pods:
    # - que estén en nodos control-plane
    # - que NO estén en namespaces excluidos
    [
      .items[]
      | select(
          (.spec.nodeName as $n
            | $controlPlanes | index($n))
          and
          (.metadata.namespace | IN($excludedNamespaces[]) | not)
        )
    ]
    # Agrupar por nodo
    | group_by(.spec.nodeName)
    | map({
        node: .[0].spec.nodeName,
        count: length
      })
  ' <<< "$RESPONSE_PODS")

  # Convertir resultados en mapa para lookup rápido
  declare -A NODE_COUNTS

  while read -r node count; do
    NODE_COUNTS["$node"]="$count"
  done < <(jq -r '.[] | "\(.node) \(.count)"' <<< "$RESULTS")

  # 5️⃣ Reportar para todos los control-plane nodes
  for NODE in $(jq -r '.[]' <<< "$CONTROL_PLANE_JSON"); do

    COUNT=${NODE_COUNTS[$NODE]:-0}

    if [ "$COUNT" -eq 0 ]; then
      log_success "✔ Sin pods - Nodo: $NODE"
    else
      log_error "✖ Con pods - Nodo: $NODE (Cantidad: %s)" "$COUNT"
    fi
  done
}

check_control_plane_pods
