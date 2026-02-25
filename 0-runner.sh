#!/bin/bash

# -----------------------------
# Configuración general
# -----------------------------
SCRIPT_DIR="./scripts"
PROFILES_DIR="./profiles"
CLUSTERS_FILE="clusters.ndjson"
EXCLUSIONES_FILE="exclusiones.txt"
RESULTS_DIR="resultados"
TOTAL_WIDTH=80

PROFILE="${1:-daily}"
PROFILE_FILE="${PROFILES_DIR}/${PROFILE}.list"

skip_cluster=false

RUN_DATE=$(date +%F)
STARTED_AT=$(date -Iseconds)

mkdir -p "$RESULTS_DIR"
rm -f "$RESULTS_DIR"/*.log

# -----------------------------
# Validar perfil
# -----------------------------
if [[ ! -f "$PROFILE_FILE" ]]; then
  echo -e "\e[38;5;196m[ERROR] Perfil '$PROFILE' no encontrado (${PROFILE_FILE})\e[0m"
  exit 1
fi

echo -e "\e[38;5;45m[INFO] Perfil activo: ${PROFILE} (default=daily)\e[0m"

# -----------------------------
# Leer scripts del perfil
# -----------------------------
mapfile -t PROFILE_SCRIPTS < <(grep -vE '^\s*#|^\s*$' "$PROFILE_FILE")

should_run_script() {
  local script_name=$1
  for s in "${PROFILE_SCRIPTS[@]}"; do
    [[ "$s" == "*" ]] && return 0
    [[ "$s" == "$script_name" ]] && return 0
  done
  return 1
}

# -----------------------------
# Leer exclusiones
# -----------------------------
EXCLUDED_CLUSTERS=()
if [[ -f "$EXCLUSIONES_FILE" ]]; then
  mapfile -t EXCLUDED_CLUSTERS < "$EXCLUSIONES_FILE"
else
  echo -e "\e[38;5;245m[AVISO] No se encontró exclusiones.txt. Se procesarán todos los clusters.\e[0m"
fi

should_skip_cluster() {
  local cluster=$1
  for excl in "${EXCLUDED_CLUSTERS[@]}"; do
    [[ "$cluster" == "$excl" ]] && return 0
  done
  return 1
}

# -----------------------------
# Procesar clusters (NDJSON)
# -----------------------------
while IFS= read -r line || [[ -n "$line" ]]; do

  [[ -z "$line" ]] && continue

  if ! echo "$line" | jq -e '
      has("name") and
      has("api") and (.api | has("ip")) and
      has("auth") and (.auth | has("token") and has("ca_cert_b64"))
    ' >/dev/null; then
    echo -e "\e[38;5;196m[ERROR] Línea inválida en clusters.ndjson:\e[0m"
    echo "$line"
    continue
  fi

  CLUSTER_NAME=$(jq -r '.name' <<<"$line")
  ENV=$(jq -r '.env // "unknown"' <<<"$line")
  CRITICALITY=$(jq -r '.criticality // "unknown"' <<<"$line")

  TOKEN=$(jq -r '.auth.token' <<<"$line")
  CERTIFICATE=$(jq -r '.auth.ca_cert_b64' <<<"$line")
  IP=$(jq -r '.api.ip' <<<"$line")

  if [[ "$TOKEN" != eyJ* ]]; then
    echo -e "\e[38;5;196m[ERROR] Token para $CLUSTER_NAME no parece JWT válido\e[0m"
    continue
  fi

  if should_skip_cluster "$CLUSTER_NAME"; then
    echo -e "\e[38;5;245m>>>>> Omitiendo cluster $CLUSTER_NAME (exclusiones.txt)\e[0m"
    continue
  fi

  REMAINING_WIDTH=$((TOTAL_WIDTH - 32 - ${#CLUSTER_NAME}))
  printf "\e[38;5;214m===========Cluster: %-*s%*s\e[0m\n" \
    32 "$CLUSTER_NAME" \
    "$REMAINING_WIDTH" \
    "================================================================================="

  echo -e "\e[38;5;245m[CTX] env=${ENV} | criticality=${CRITICALITY}\e[0m"

  for script in "$SCRIPT_DIR"/*.sh; do
    [[ -x "$script" ]] || continue

    script_name=$(basename "$script")
    should_run_script "$script_name" || continue

    log_file="${RESULTS_DIR}/${script_name%.sh}.log"

    output=$("$script" "$CLUSTER_NAME" "$TOKEN" "$CERTIFICATE" "$IP")
    status=$?

    {
      echo "======= ${CLUSTER_NAME} | env=${ENV} | criticality=${CRITICALITY} ======="
      echo "$output"
    } >> "$log_file"

    echo "$output"

    if [[ "$script_name" == "1-test-api.sh" && $status -ne 0 ]]; then
      echo -e "\e[38;5;202m>>>>> Falló test_api. Saltando al próximo cluster\e[0m"
      skip_cluster=true
      break
    fi
  done

  $skip_cluster && skip_cluster=false && continue

done < "$CLUSTERS_FILE"


cat > ${RESULTS_DIR}/run.json <<EOF
{
  "run_id": "${RUN_DATE}",
  "profile": "${PROFILE}",
  "started_at": "${STARTED_AT}",
  "finished_at": "$(date -Iseconds)",
  "status": "completed"
}
EOF
