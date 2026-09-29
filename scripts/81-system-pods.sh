#!/usr/bin/env bash
set -uo pipefail
IFS=$'\n\t'

CLUSTER_NAME=$1
TOKEN=$2
CERTIFICATE=$3
IP=$4
ENV=$5

#LOG_LEVEL=INFO

if [[ "${ENV,,}" == "prod" || "${ENV,,}" == "production" ]]; then
  MAX_RESTARTS=0
else
  MAX_RESTARTS=3
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

source "$ROOT_DIR/lib/log.sh"

log_info "Entorno: $ENV - MAX_RESTARTS: $MAX_RESTARTS"

source "$ROOT_DIR/lib/api.sh"
source "$ROOT_DIR/lib/ns.sh"
source "$ROOT_DIR/lib/exclusiones-operaciones.sh"

ERR_COUNT=0
if ! load_operation_exclusions "$CLUSTER_NAME"; then
  exit 1
fi

check_optional_namespace() {
  local ns="$1"
  local response

  response=$(api_get "$IP" "$TOKEN" "/api/v1/namespaces/$ns")

  if jq -e '.kind == "Namespace"' <<<"$response" >/dev/null 2>&1; then
    return 0
  fi

  if jq -e '.kind == "Status" and .reason == "NotFound"' <<<"$response" >/dev/null 2>&1; then
    log_info "Namespace:$ns NamespaceNotFound (omitido por configuración)"
    return 10
  fi

  log_error "Namespace:$ns InvalidAPIResponse"
  ((ERR_COUNT++))
  return 1
}

log_zone "Chequeo de Pods, Deployments, StatefulSets y DaemonSets de sistema"

# ==========================
# 🚀 POD CHECK (OPTIMIZADO)
# ==========================

check_pods() {
  local ns="$1"
  log_info "----- Checking Pods in namespace=$ns -----"

  response=$(api_get "$IP" "$TOKEN" "/api/v1/namespaces/$ns/pods")

  if jq -e '.kind == "Status" and .reason == "NotFound"' <<<"$response" >/dev/null 2>&1; then
    if is_namespace_optional "$ns"; then
      return 10
    else
      log_error "Namespace:$ns NamespaceNotFound"
      ((ERR_COUNT++))
    fi
    return
  fi

  if ! jq -e '.kind == "PodList" and (.items | type == "array")' <<<"$response" >/dev/null 2>&1; then
    log_error "Namespace:$ns InvalidAPIResponse"
    ((ERR_COUNT++))
    return
  fi

  pod_count=$(jq '.items | length' <<<"$response")
  log_info "Pods count: $pod_count"

  if [[ "$pod_count" -eq 0 ]]; then
    log_error "Namespace:$ns NoPodsFound"
    ((ERR_COUNT++))
    return
  fi

  errors=$(jq -r \
    --arg ns "$ns" \
    --argjson max_restarts "$MAX_RESTARTS" '
    .items[] as $pod
    |
    ($pod.metadata.name) as $pod_name
    |
    ($pod.status.phase // "") as $phase
    |
    ([ $pod.metadata.ownerReferences[]?.kind ] | any(.=="Job")) as $is_job
    |
    (
      # 🔹 Lógica especial para Jobs
      if $is_job then
        if $phase=="Failed" then
          "Namespace:\($ns) Pod:\($pod_name) JobFailed"
        else
          empty
        end

      # 🔹 Lógica normal para Pods NO Job
      else
        (
          if ($phase!="Running" and $phase!="Succeeded") then
            "Namespace:\($ns) Pod:\($pod_name) Phase=\($phase)"
          else empty end
        ),
        (
          $pod.status.containerStatuses[]? as $c
          |
          ($c.name) as $cname
          |
          ($c.ready) as $ready
          |
          ($c.restartCount) as $restarts
          |
          ($c.state.waiting.reason // "") as $reason
          |
          if $reason=="CrashLoopBackOff"
             or $reason=="ErrImagePull"
             or $reason=="ImagePullBackOff"
          then
            "Namespace:\($ns) Pod:\($pod_name) Container:\($cname) Reason=\($reason)"
          elif $restarts > $max_restarts then
            "Namespace:\($ns) Pod:\($pod_name) Container:\($cname) HighRestarts=\($restarts)"
          elif $ready!=true then
            "Namespace:\($ns) Pod:\($pod_name) Container:\($cname) NotReady"
          else empty end
        )
      end
    )
  ' <<<"$response")

  if [[ -n "$errors" ]]; then
    while IFS= read -r line; do
      log_error "$line"
      ((ERR_COUNT++))
    done <<<"$errors"
  fi
}

# ==========================
# 📦 DEPLOYMENTS
# ==========================
check_deployments() {
  local ns="$1"
  log_info "----- Checking Deployments in namespace=$ns -----"

  response=$(api_get "$IP" "$TOKEN" "/apis/apps/v1/namespaces/$ns/deployments")

  errors=$(jq -r --arg ns "$ns" '
    .items[]
    | select((.status.readyReplicas // 0) < (.spec.replicas // 0))
    | "Namespace:\($ns) Deployment:\(.metadata.name) Ready:\(.status.readyReplicas // 0)/\(.spec.replicas // 0)"
  ' <<<"$response")

  if [[ -n "$errors" ]]; then
    while IFS= read -r line; do
      log_error "$line"
      ((ERR_COUNT++))
    done <<<"$errors"
  fi
}

# ==========================
# 📦 STATEFULSETS
# ==========================
check_statefulsets() {
  local ns="$1"
  log_info "----- Checking StatefulSets in namespace=$ns -----"

  response=$(api_get "$IP" "$TOKEN" "/apis/apps/v1/namespaces/$ns/statefulsets")

  errors=$(jq -r --arg ns "$ns" '
    .items[]
    | select((.status.readyReplicas // 0) < (.spec.replicas // 0))
    | "Namespace:\($ns) StatefulSet:\(.metadata.name) Ready:\(.status.readyReplicas // 0)/\(.spec.replicas // 0)"
  ' <<<"$response")

  if [[ -n "$errors" ]]; then
    while IFS= read -r line; do
      log_error "$line"
      ((ERR_COUNT++))
    done <<<"$errors"
  fi
}

# ==========================
# 📦 DAEMONSETS
# ==========================
check_daemonsets() {
  local ns="$1"
  log_info "----- Checking DaemonSets in namespace=$ns -----"

  response=$(api_get "$IP" "$TOKEN" "/apis/apps/v1/namespaces/$ns/daemonsets")

  errors=$(jq -r --arg ns "$ns" '
    .items[]
    | select((.status.numberReady // 0) < (.status.desiredNumberScheduled // 0))
    | "Namespace:\($ns) DaemonSet:\(.metadata.name) Ready:\(.status.numberReady // 0)/\(.status.desiredNumberScheduled // 0)"
  ' <<<"$response")

  if [[ -n "$errors" ]]; then
    while IFS= read -r line; do
      log_error "$line"
      ((ERR_COUNT++))
    done <<<"$errors"
  fi
}

check_namespace() {
  local ns="$1"

  if is_namespace_optional "$ns"; then
    check_optional_namespace "$ns"
    case "$?" in
      0) ;;
      10) return 0 ;;
      *) return 1 ;;
    esac
  fi

  check_pods "$ns"
  [[ "$?" -eq 10 ]] && return
  check_deployments "$ns"
  check_statefulsets "$ns"
  check_daemonsets "$ns"
}

main() {
  namespaces=$(jq -r '.[]' <<< "$NAMESPACES_JSON")

  for ns in $namespaces; do
    check_namespace "$ns"
  done

  if [[ "$ERR_COUNT" -eq 0 ]]; then
    log_success "✔  Todos los workloads de sistema OK"
  else
    log_error "Se encontraron $ERR_COUNT errores en el cluster $CLUSTER_NAME"
  fi

  exit 0
}

main
