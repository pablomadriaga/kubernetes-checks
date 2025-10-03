#!/bin/bash

CLUSTER_NAME=$1
TOKEN=$2
CERTIFICATE=$3
IP=$4
CLUSTER_URL="https://$IP:6443"

# Definir los namespaces a excluir
EXCLUDED_NAMESPACES=("kube-system" "tanzu-system" "tanzu-system-ingress" "tanzu-system-monitoring" \
"vmware-system-auth" "vmware-system-cloud-provider" "vmware-system-csi" "vmware-system-tmc" \
"vmware-system-tsm" "tkg-system" "cert-manager" "gatekeeper-system" \
"tanzu-observability-saas" "tanzu-package-repo-global")

# Convertir el array de namespaces a formato JSON para jq
EXCLUDED_JSON=$(echo "${EXCLUDED_NAMESPACES[@]}" | jq -R -s 'split(" ")')

printf "\e[32m===Cantidad de contenedores sin livenessProbe o readinessProbe===\e[0m\n"

# Obtener todos los deployments
RESPONSE=$(curl -k -s -X GET "$CLUSTER_URL/apis/apps/v1/deployments" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json")

# Verificar que la solicitud fue exitosa
if [ $? -ne 0 ] || [ -z "$RESPONSE" ]; then
  echo "  Error: Falló la solicitud a la API de deployments."
  exit 1
fi

# Contar contenedores sin livenessProbe
NO_LIVENESS=$(echo "$RESPONSE" | jq --argjson excludedNamespaces "$EXCLUDED_JSON" '
  [.items[] | select(.metadata.namespace | IN($excludedNamespaces[]) | not)
   | .spec.template.spec.containers[]
   | select(.livenessProbe == null)
  ] | length')

# Contar contenedores sin readinessProbe
NO_READINESS=$(echo "$RESPONSE" | jq --argjson excludedNamespaces "$EXCLUDED_JSON" '
  [.items[] | select(.metadata.namespace | IN($excludedNamespaces[]) | not)
   | .spec.template.spec.containers[]
   | select(.readinessProbe == null)
  ] | length')

# Mostrar resultados con ✔/✖
if [ "$NO_LIVENESS" -eq 0 ]; then
  printf "  \e[38;5;34m✔ Todos los contenedores tienen livenessProbe - OK\e[0m\n"
else
  printf "  \e[31m✖ Contenedores sin livenessProbe: %s\e[0m\n" "$NO_LIVENESS"
fi

if [ "$NO_READINESS" -eq 0 ]; then
  printf "  \e[38;5;34m✔ Todos los contenedores tienen readinessProbe - OK\e[0m\n"
else
  printf "  \e[31m✖ Contenedores sin readinessProbe: %s\e[0m\n" "$NO_READINESS"
fi

# Salir con código 1 si hubo algún error
if [ "$NO_LIVENESS" -gt 0 ] || [ "$NO_READINESS" -gt 0 ]; then
  exit 1
fi

