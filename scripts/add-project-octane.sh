#!/usr/bin/env bash
set -e

PROJECT_NAME="$1"
DOMAIN="$2"
REDIS_DB="$3"

if [ -z "$PROJECT_NAME" ] || [ -z "$DOMAIN" ] || [ -z "$REDIS_DB" ]; then
  echo "Uso: add-project-octane.sh projeto dominio redis_db"
  exit 1
fi

get_free_port() {
  for port in {8000..9000}; do
    if ! ss -lnt | awk '{print $4}' | grep -q ":$port$"; then
      echo $port; return
    fi
  done
  echo "Sem porta livre"; exit 1
}

PORT=$(get_free_port)

echo "Projeto $PROJECT_NAME criado na porta $PORT"
