#!/bin/bash

CLUSTER_NAME=$1
TOKEN=$2
CERTIFICATE=$3
IP=$4
CLUSTER_URL="https://$IP:6443"

check_control_plane_pods() {
  printf "\e[32m=== Analizando pods en nodos del control plane ===\e[0m\n"

  RESPONSE_NODES=$(curl -k -s -X GET "$CLUSTER_URL/api/v1/nodes" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json")

  CONTROL_PLANE_NODES=$(echo "$RESPONSE_NODES" | jq -r '
    .items[] |
    select(.spec.taints[]?.key=="node-role.kubernetes.io/control-plane") |
    .metadata.name
  ')

  if [ -z "$CONTROL_PLANE_NODES" ]; then
    echo "No se encontraron nodos control plane."
    return
  fi

  for NODE in $CONTROL_PLANE_NODES; do
    RESPONSE_PODS=$(curl -k -s -X GET "$CLUSTER_URL/api/v1/pods?fieldSelector=spec.nodeName=$NODE" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json")

    PODS_COUNT=$(echo "$RESPONSE_PODS" | jq '[.items[] |
      select(
          (.metadata.namespace != "kube-system")
          and (.metadata.namespace != "tanzu-system-ingress")
          and (.metadata.namespace != "tanzu-system-logging")
          and (.metadata.namespace != "tanzu-system-monitoring")
          and (.metadata.namespace != "velero")
          and (.metadata.namespace != "vmware-system-auth")
          and (.metadata.namespace != "vmware-system-cloud-provider")
          and (.metadata.namespace != "vmware-system-csi")
          and (.metadata.namespace != "tkg-system")
          and (.metadata.namespace != "vmware-system-tmc")
      )] | length')

    if [ "$PODS_COUNT" -eq 0 ]; then
      printf "  \e[38;5;34m✔ Sin pods - Nodo: $NODE\e[0m\n"
    else
      printf "  \e[31m✖ Con pods - Nodo: $NODE (Cantidad: %s)\e[0m\n" "$PODS_COUNT"
    fi
  done
}

check_control_plane_pods

