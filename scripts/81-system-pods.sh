#!/bin/bash

CLUSTER_NAME=$1
TOKEN=$2
CERTIFICATE=$3
IP=$4
CLUSTER_URL="https://$IP:6443"

check_namespace_pods_health() {
  NAMESPACES=("kube-system" "tanzu-system" "tanzu-system-monitoring" \
              "vmware-system-auth" "vmware-system-cloud-provider" \
              "vmware-system-csi" "vmware-system-tmc" "gatekeeper-system")

  printf "\e[32m=== Chequeando pods críticos ===\e[0m\n"

  for NS in "${NAMESPACES[@]}"; do
    echo -e " Namespace: $NS"

    RESPONSE=$(curl -k -s -X GET "$CLUSTER_URL/api/v1/namespaces/$NS/pods" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json")

    PODS=$(echo "$RESPONSE" | jq -r '.items[] | {name: .metadata.name, phase: .status.phase, conditions: .status.conditions}')

    if [ -z "$PODS" ]; then
      echo "  No se encontraron pods en $NS."
      continue
    fi

    NO_HEALTH=0

    while read -r pod; do
      NAME=$(echo "$pod" | jq -r '.name')
      PHASE=$(echo "$pod" | jq -r '.phase')
      READY=$(echo "$pod" | jq -r '.ready')

      if { [[ "$PHASE" != "Running" || "$READY" != "true" ]] && [[ "$PHASE" != "Succeeded" ]]; }; then
        printf "  \e[31m✖ %s: Phase=%s Ready=%s\e[0m\n" "$NAME" "$PHASE" "$READY"
        NO_HEALTH=1
      fi
    done < <(echo "$RESPONSE" | jq -r '.items[] |
      {
        name: .metadata.name,
        phase: .status.phase,
        ready: ([.status.conditions[]? | select(.type=="Ready") | .status] | any(.=="True"))
      }' | jq -c '.')

    if [ "$NO_HEALTH" -eq 0 ]; then
      printf "  \e[38;5;34m✔ Todos los pods en %s están OK\e[0m\n" "$NS"
    fi

  done
}

check_namespace_pods_health

