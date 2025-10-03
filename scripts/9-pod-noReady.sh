#!/bin/bash
CLUSTER_NAME=$1
TOKEN=$2
CERTIFICATE=$3
IP=$4
CLUSTER_URL="https://$IP:6443"
WIDTH=$(tput cols)
MAX_NS=$((WIDTH / 3)) # dejamos 15 columnas para PROBLEM_PODS

EXCLUDED_NAMESPACES=("kube-system" "tanzu-system" "tanzu-system-ingress" "tanzu-system-monitoring" \
"vmware-system-auth" "vmware-system-cloud-provider" "vmware-system-csi" "vmware-system-tmc" \
"vmware-system-tsm" "tkg-system" "cert-manager" "gatekeeper-system" \
"tanzu-observability-saas" "tanzu-package-repo-global")

# Convertir array a JSON para jq
EXCLUDED_JSON=$(echo "${EXCLUDED_NAMESPACES[@]}" | jq -R -s 'split(" ")')

check_tools() {
  command -v jq >/dev/null 2>&1 || { echo "ERROR: jq no está instalado."; exit 1; }
  command -v curl >/dev/null 2>&1 || { echo "ERROR: curl no está instalado."; exit 1; }
}

get_problem_pods_two_calls() {
  printf "\e[32m===Analizando Pods===\e[0m\n"

  RAW1=$(curl -k -s -G "$CLUSTER_URL/api/v1/pods" --data-urlencode 'fieldSelector=status.phase!=Running,status.phase!=Succeeded' \
    -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json")

  RAW2=$(curl -k -s -G "$CLUSTER_URL/api/v1/pods" --data-urlencode 'fieldSelector=status.phase=Running' \
    -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json")

  PROB_RUNNING=$(echo "$RAW2" | jq --argjson excludedNamespaces "$EXCLUDED_JSON" '
    .items // [] |
    map(
      ( .status.conditions // [] | map(select(.type=="Ready")) | .[0]? ) as $cond |
      ( .status.containerStatuses // [] ) as $cs |
      {
        namespace: .metadata.namespace,
        name: .metadata.name,
        phase: (.status.phase // "Unknown"),
        readyCount: ($cs | map(select(.ready==true)) | length),
        totalCount: ($cs | length),
        podReadyCond: ($cond.status // "Unknown"),
        restarts: ($cs | map(.restartCount) | add // 0)
      } |
      select(
        (.totalCount > 0 and .readyCount < .totalCount)
        or
        (.totalCount == 0 and .podReadyCond != "True")
      ) |
      select(.namespace | IN($excludedNamespaces[]) | not)
    )
  ')

  PROB_NONRUN=$(echo "$RAW1" | jq --argjson excludedNamespaces "$EXCLUDED_JSON" '
    .items // [] |
    map({
      namespace: .metadata.namespace,
      name: .metadata.name,
      phase: (.status.phase // "Unknown"),
      reason: (.status.reason // ""),
      message: (.status.message // ""),
      restarts: ((.status.containerStatuses // []) | map(.restartCount) | add // 0)
    }) |
    map(select(.namespace | IN($excludedNamespaces[]) | not))
  ')

  COMBINED=$(echo "$PROB_NONRUN" "$PROB_RUNNING" | jq -s 'add')

  # Chequear si no hay pods con problemas
  if [ "$(echo "$COMBINED" | jq 'length')" -eq 0 ]; then
    printf "  \e[38;5;34m✔ Todos los pods están OK\e[0m\n"
    return
  fi

  # Si hay problemas, mostrar tabla
  printf "%-${MAX_NS}s %-${WIDTH}s\n" "  NAMESPACE" "PROBLEM_PODS"
  echo "$COMBINED" | jq -r '
    group_by(.namespace) |
    map({namespace: .[0].namespace, problem_pods: length}) |
    .[] | "\(.namespace)\t\(.problem_pods)"
  ' | awk -F'\t' -v maxns="$MAX_NS" '{
    ns=$1;
    if(length(ns)>maxns) ns=substr(ns,1,maxns-3)"...";
    printf "  %-*s %s\n", maxns, ns, $2
  }'
}

check_tools
get_problem_pods_two_calls

