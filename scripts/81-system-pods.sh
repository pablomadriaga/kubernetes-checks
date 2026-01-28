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

    POD_COUNT=$(echo "$RESPONSE" | jq '.items | length')

    if [ "$POD_COUNT" -eq 0 ]; then
      echo "  No se encontraron pods en $NS."
      continue
    fi

    NO_HEALTH=0

    while read -r pod; do
      NAME=$(echo "$pod" | jq -r '.name')
      PHASE=$(echo "$pod" | jq -r '.phase')
      READY=$(echo "$pod" | jq -r '.ready')
      IS_JOB=$(echo "$pod" | jq -r '.isJob')

      if [ "$IS_JOB" = "true" ]; then
        # Pods efímeros (Job / CronJob)
        if [ "$PHASE" = "Failed" ]; then
          printf "  \e[31m✖ %s (Job): Phase=%s\e[0m\n" "$NAME" "$PHASE"
          NO_HEALTH=1
        fi
      else
        # Pods long-lived
        if { [[ "$PHASE" != "Running" || "$READY" != "true" ]] && [[ "$PHASE" != "Succeeded" ]]; }; then
          printf "  \e[31m✖ %s: Phase=%s Ready=%s\e[0m\n" "$NAME" "$PHASE" "$READY"
          NO_HEALTH=1
        fi
      fi

    done < <(
      echo "$RESPONSE" | jq -c '
        .items[] |
        {
          name: .metadata.name,
          phase: .status.phase,
          ready: (
            [.status.conditions[]? | select(.type=="Ready") | .status]
            | any(. == "True")
          ),
          isJob: (
            [.metadata.ownerReferences[]? | .kind]
            | any(. == "Job")
          )
        }
      '
    )

    if [ "$NO_HEALTH" -eq 0 ]; then
      printf "  \e[38;5;34m✔ Todos los pods están saludables\e[0m\n"
    fi

  done
}

check_namespace_pods_health
