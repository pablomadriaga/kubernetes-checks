#!/usr/bin/env bash
set -uo pipefail
IFS=$'\n\t'

# ==========================
# 📦 Configuración
# ==========================
readonly SCRIPT_DIR="./scripts"
readonly PROFILES_DIR="./profiles"
readonly CLUSTERS_FILE="./config/clusters.ndjson"
readonly EXCLUSIONES_FILE="./config/exclusiones.txt"
readonly RESULTS_DIR="./resultados"
readonly LIB_DIR="./lib"

readonly TOTAL_WIDTH=80
readonly PROFILE="${1:-daily}"
readonly PROFILE_FILE="${PROFILES_DIR}/${PROFILE}.list"

readonly RUN_DATE="$(date +%F)"
readonly STARTED_AT="$(date -Iseconds)"

LOG_LEVEL=INFO

# ==========================
# 📚 Cargar librerías
# ==========================
source "${LIB_DIR}/log.sh"
source "${LIB_DIR}/api.sh"

# ==========================
# 🔧 Utilidades
# ==========================
load_profile() {
  if [[ ! -f "$PROFILE_FILE" ]]; then
    log_error "Perfil '$PROFILE' no encontrado (${PROFILE_FILE})"
    exit 1
  fi

  log_info "Perfil activo: ${PROFILE}"

  mapfile -t PROFILE_SCRIPTS < <(
    grep -vE '^\s*#|^\s*$' "$PROFILE_FILE"
  )
}

should_run_script() {
  local script_name=$1

  for s in "${PROFILE_SCRIPTS[@]}"; do
    [[ "$s" == "*" ]] && return 0
    [[ "$s" == "$script_name" ]] && return 0
  done

  return 1
}

load_exclusions() {
  EXCLUDED_CLUSTERS=()

  if [[ -f "$EXCLUSIONES_FILE" ]]; then
    mapfile -t EXCLUDED_CLUSTERS < <(
      sed 's/\r$//; s/[[:space:]]*$//' "$EXCLUSIONES_FILE" |
      grep -vE '^\s*$'
    )
    log_info "Exclusiones cargadas: ${#EXCLUDED_CLUSTERS[@]}"
  else
    log_warn "No se encontró exclusiones.txt"
  fi
}

should_skip_cluster() {
  local cluster=$1

  for excl in "${EXCLUDED_CLUSTERS[@]}"; do
    [[ "$cluster" == "$excl" ]] && return 0
  done

  return 1
}

run_scripts_for_cluster() {
  local cluster_name=$1
  local env=$2
  local criticality=$3
  local token=$4
  local certificate=$5
  local ip=$6

  for script in "$SCRIPT_DIR"/*.sh; do
    [[ -x "$script" ]] || continue

    local script_name
    script_name=$(basename "$script")

    should_run_script "$script_name" || continue

    local log_file="${RESULTS_DIR}/${script_name%.sh}.log"

    # Header en archivo
    {
      printf "======= %s | env=%s | criticality=%s =======\n" \
        "$cluster_name" "$env" "$criticality"
    } >> "$log_file"

    # Ejecutar mostrando salida en tiempo real y guardando en archivo
    "$script" "$cluster_name" "$token" "$certificate" "$ip" \
      | tee -a "$log_file"

    local exit_code=${PIPESTATUS[0]}

    # Si hubo error técnico real (exit != 0)
    if [[ "$exit_code" -ne 0 ]]; then
      log_info "Error técnico ejecutando $script_name en $cluster_name (exit=$exit_code)"
    fi
  done
}

process_clusters() {
  while IFS= read -r line || [[ -n "$line" ]]; do

    [[ -z "$line" ]] && continue

    local cluster_name
    cluster_name=$(jq -r '.name' <<<"$line")

    local env
    env=$(jq -r '.env // "unknown"' <<<"$line")

    local criticality
    criticality=$(jq -r '.criticality // "unknown"' <<<"$line")

    local token
    token=$(jq -r '.auth.token' <<<"$line")

    local certificate
    certificate=$(jq -r '.auth.ca_cert_b64' <<<"$line")

    local ip
    ip=$(jq -r '.api.ip' <<<"$line")

    if should_skip_cluster "$cluster_name"; then
      log_zone "Cluster $cluster_name excluido por configuración"
      continue
    fi

    log_section "Cluster: $cluster_name"
    log_info "env=${env} | criticality=${criticality}"

    if ! api_health_check "$ip" "$token"; then
      log_error "API cluster $cluster_name no responde. Saltando cluster."
      continue
    fi

    log_success "API cluster $cluster_name OK"

    run_scripts_for_cluster \
      "$cluster_name" \
      "$env" \
      "$criticality" \
      "$token" \
      "$certificate" \
      "$ip"

  done < "$CLUSTERS_FILE"
}

write_run_metadata() {
  cat > "${RESULTS_DIR}/run.json" <<EOF
{
  "run_id": "${RUN_DATE}",
  "profile": "${PROFILE}",
  "started_at": "${STARTED_AT}",
  "finished_at": "$(date -Iseconds)",
  "status": "completed"
}
EOF
}

prepare_environment() {
  mkdir -p "$RESULTS_DIR"
  rm -f "$RESULTS_DIR"/*.log
}

# ==========================
# 🚀 Main
# ==========================
main() {
  prepare_environment
  load_profile
  load_exclusions
  process_clusters
  write_run_metadata
}

main "$@"
