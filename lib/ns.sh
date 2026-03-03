#!/usr/bin/env bash

NS_CONFIG_DIR="$ROOT_DIR/config/ns"

load_all_ns_files() {

  # Si no existe el directorio → devolver array vacío
  [[ -d "$NS_CONFIG_DIR" ]] || {
    echo "[]"
    return
  }

  # Leer todos los .txt
  find "$NS_CONFIG_DIR" -type f -name "*.txt" 2>/dev/null \
    | while read -r file; do
        sed '/^[[:space:]]*$/d' "$file" \
        | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
      done \
    | sort -u \
    | jq -R . \
    | jq -s .
}

NAMESPACES_JSON=$(load_all_ns_files)

# Helper bash puro
is_namespace() {
  local ns="$1"
  grep -Fxq "$ns" "$NS_CONFIG_DIR"/*.txt 2>/dev/null
}
