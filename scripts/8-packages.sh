#!/bin/bash

CLUSTER_NAME=$1
TOKEN=$2
CERTIFICATE=$3
IP=$4
CLUSTER_URL="https://$IP:6443"

check_packages_status() {
  printf "\e[32m=== Analizando Packages===\e[0m\n"

  RESPONSE=$(curl -k -s -X GET "$CLUSTER_URL/apis/kappctrl.k14s.io/v1alpha1/apps" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json")

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
    printf "  \e[38;5;34m✔ Todos los Packages están OK\e[0m\n"
  else
    printf "  \e[31m✖ Packages con error: %s\e[0m\n" "$ERRORS_COUNT"
    echo "  Nombres de Packages con error:"
    echo "$ERRORS" | jq -r '.[] | "    \(.namespace)/\(.name)"'
    exit 1
  fi
}

check_packages_status

