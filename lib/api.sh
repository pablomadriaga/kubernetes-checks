#!/usr/bin/env bash

api_get() {
  local ip="$1"
  local token="$2"
  local path="$3"

  local cluster_url="https://${ip}:6443"

  curl -k -s \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Type: application/json" \
    "${cluster_url}${path}"
}

api_health_check() {
  log_zone "Test de conexión API..."
  local ip="$1"
  local token="$2"

  local cluster_url="https://${ip}:6443"

  local response
  response=$(curl -k -s \
    -H "Authorization: Bearer ${token}" \
    "${cluster_url}/healthz")

  [[ "$response" == "ok" ]]
}
