#!/usr/bin/env bash

# ==========================
# 🎨 Colores
# ==========================
COLOR_DEBUG="\e[90m"        # Gris
COLOR_INFO="\e[36m"         # Cyan
COLOR_SUCCESS="\e[32m"      # Verde
COLOR_WARN="\e[33m"         # Amarillo
COLOR_ERROR="\e[31m"        # Rojo
COLOR_SECTION="\e[38;5;214m"
COLOR_ZONE="\e[38;5;179m"   # Naranja tenue
COLOR_RESET="\e[0m"

# ==========================
# 📊 Log Levels
# ==========================
# Orden jerárquico:
# DEBUG < INFO < WARN < ERROR
#
# SUCCESS es especial:
# - Siempre visible (como ERROR)
# - No afecta jerarquía
#

LOG_LEVEL="${LOG_LEVEL:-ERROR}"

level_to_number() {
  case "$1" in
    DEBUG) echo 0 ;;
    INFO)  echo 1 ;;
    WARN)  echo 2 ;;
    ERROR) echo 3 ;;
    *)     echo 1 ;;
  esac
}

CURRENT_LEVEL=$(level_to_number "$LOG_LEVEL")

# ==========================
# 🧠 Core Logger
# ==========================

log() {
  local level="$1"
  local color="$2"
  shift 2

  local level_num
  level_num=$(level_to_number "$level")

  # SUCCESS y ERROR siempre visibles
  if [[ "$level" == "SUCCESS" || "$level" == "ERROR" ]]; then
    printf "  ${color}[%s] " "$level"
    printf "$@"
    printf "${COLOR_RESET}\n"
    return
  fi

  if [[ "$level_num" -ge "$CURRENT_LEVEL" ]]; then
    printf "    ${color}[%s] " "$level"
    printf "$@"
    printf "${COLOR_RESET}\n"
  fi
}

# ==========================
# 🧩 Wrappers
# ==========================
log_debug()   { log "DEBUG"   "$COLOR_DEBUG"   "$@"; }
log_info()    { log "INFO"    "$COLOR_INFO"    "$@"; }
log_success() { log "SUCCESS" "$COLOR_SUCCESS" "$@"; }
log_warn()    { log "WARN"    "$COLOR_WARN"    "$@"; }
log_error()   { log "ERROR"   "$COLOR_ERROR"   "$@"; }

log_section() {
  local message="$1"
  printf "\n${COLOR_SECTION}========== %s ==========${COLOR_RESET}\n" "$message"
}

log_zone() {
  local message="$1"
  printf "${COLOR_ZONE}---------- %s ----------${COLOR_RESET}\n" "$message"
}
