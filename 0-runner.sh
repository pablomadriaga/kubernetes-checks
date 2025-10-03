#!/bin/bash

SCRIPT_DIR="./scripts"
CLUSTERS_FILE="clusters.txt"
EXCLUSIONES_FILE="exclusiones.txt"
RESULTS_DIR="resultados"
TOTAL_WIDTH=80
skip_cluster=false

mkdir -p "$RESULTS_DIR"
rm -f "$RESULTS_DIR"/*.log

# Leer exclusiones en un array (si existe el archivo)
EXCLUDED_CLUSTERS=()
if [[ -f "$EXCLUSIONES_FILE" ]]; then
  mapfile -t EXCLUDED_CLUSTERS < "$EXCLUSIONES_FILE"
else
  echo -e "\e[38;5;245m[AVISO] No se encontró exclusiones.txt. Se procesarán todos los clusters.\e[0m"
fi

# Función para saber si un cluster está en exclusiones
should_skip() {
  local cluster=$1
  for excl in "${EXCLUDED_CLUSTERS[@]}"; do
    if [[ "$cluster" == "$excl" ]]; then
      return 0  # true → debe ser omitido
    fi
  done
  return 1  # false → no está excluido
}

# Leer cada línea del archivo clusters.txt
while IFS= read -r line || [ -n "$line" ]; do
  CLUSTER_NAME=$(echo "$line" | awk -F'\t' '{print $1}')
  TOKEN=$(echo "$line" | awk -F'\t' '{print $2}')
  CERTIFICATE=$(echo "$line" | awk -F'\t' '{print $3}')
  IP=$(echo "$line" | awk -F'\t' '{print $4}')

  # Verificar exclusión
  if should_skip "$CLUSTER_NAME"; then
    echo -e "\e[38;5;245m>>>>> Omitiendo cluster $CLUSTER_NAME (definido en exclusiones.txt)\e[0m"
    continue
  fi

  REMAINING_WIDTH=$((TOTAL_WIDTH - 32 - ${#CLUSTER_NAME}))
  printf "\e[38;5;214m===========Cluster: %-*s%*s\e[0m\n" 32 "$CLUSTER_NAME" $REMAINING_WIDTH "================================================================================="

  for script in "$SCRIPT_DIR"/*.sh; do
    if [[ -x "$script" ]]; then
      script_name=$(basename "$script")
      log_file="${RESULTS_DIR}/${script_name%.sh}.log"

      output=$("$script" "$CLUSTER_NAME" "$TOKEN" "$CERTIFICATE" "$IP")
      status=$?
      echo "======= ${CLUSTER_NAME} ===================================================" >> "$log_file"
      echo "$output" >> "$log_file"

      echo "$output"

      if [[ "$script_name" == "1-test-api.sh" && $status -ne 0 ]]; then
          echo -e "\e[38;5;202m>>>>> Falló test_api. Saltando al proximo cluster\e[0m"
          skip_cluster=true
          break
      fi

    else
      echo "Advertencia: $script no es ejecutable."
    fi
  done

  # Si falló test_api, no seguimos con este cluster
  if $skip_cluster; then
      skip_cluster=false
      continue
  fi

done < "$CLUSTERS_FILE"

