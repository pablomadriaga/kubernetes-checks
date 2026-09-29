#!/usr/bin/env bash

OPERATION_EXCLUSIONS_FILE="$ROOT_DIR/config/exclusiones-operaciones/exclusiones.txt"
OPTIONAL_NAMESPACES=()
VELERO_OPTIONAL=0

trim_exception_value() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

load_operation_exclusions() {
  local cluster_name="$1"
  local cluster
  local exception
  local value
  local extra
  local line_number=0
  local has_errors=0

  OPTIONAL_NAMESPACES=()
  VELERO_OPTIONAL=0

  [[ -f "$OPERATION_EXCLUSIONS_FILE" ]] || return 0

  while IFS=';' read -r cluster exception value extra; do
    line_number=$((line_number + 1))

    cluster=$(trim_exception_value "${cluster:-}")
    exception=$(trim_exception_value "${exception:-}")
    value=$(trim_exception_value "${value:-}")
    extra=$(trim_exception_value "${extra:-}")

    [[ -z "$cluster" || "$cluster" == \#* ]] && continue

    if [[ -n "$extra" || -z "$exception" ]]; then
      log_error "Formato inválido en $OPERATION_EXCLUSIONS_FILE línea $line_number"
      has_errors=1
      continue
    fi

    [[ "$cluster" == "$cluster_name" ]] || continue

    case "$exception" in
      namespace-opcional)
        if [[ -z "$value" ]]; then
          log_error "Falta el namespace en $OPERATION_EXCLUSIONS_FILE línea $line_number"
          has_errors=1
        else
          OPTIONAL_NAMESPACES+=("$value")
        fi
        ;;
      velero-opcional)
        if [[ "$value" == "si" ]]; then
          VELERO_OPTIONAL=1
        else
          log_error "Valor inválido para velero-opcional en $OPERATION_EXCLUSIONS_FILE línea $line_number (use 'si')"
          has_errors=1
        fi
        ;;
      *)
        log_error "Exclusión desconocida '$exception' en $OPERATION_EXCLUSIONS_FILE línea $line_number"
        has_errors=1
        ;;
    esac
  done < <(sed 's/\r$//' "$OPERATION_EXCLUSIONS_FILE")

  return "$has_errors"
}

is_namespace_optional() {
  local ns="$1"
  local optional

  for optional in "${OPTIONAL_NAMESPACES[@]}"; do
    [[ "$optional" == "$ns" ]] && return 0
  done

  return 1
}

is_velero_optional() {
  [[ "$VELERO_OPTIONAL" -eq 1 ]]
}
