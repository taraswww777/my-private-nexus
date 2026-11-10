#!/bin/bash

# Подключаем .env из той же папки, что и скрипт
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/.env" ]; then
  set -a          # автоматически экспортировать все переменные
  source "$SCRIPT_DIR/.env"
  set +a
fi

NEXUS_URL="${NEXUS_URL:-http://localhost:8081}"
ADMIN_USER="${ADMIN_USER:?ADMIN_USER не задан}"
ADMIN_PASS="${ADMIN_PASS:?ADMIN_PASS не задан}"

echo "Ожидание запуска Nexus..."
until curl -s -o /dev/null -w "%{http_code}" "$NEXUS_URL/service/rest/v1/status" | grep -q "200"; do
  sleep 5
  echo "Nexus ещё не готов..."
done
echo "Nexus запущен."

echo "Загрузка скрипта..."
curl -X POST -u "$ADMIN_USER:$ADMIN_PASS" \
  --header 'Content-Type: application/json' \
  "$NEXUS_URL/service/rest/v1/script" \
  -d '{"name":"npm-proxy-setup","type":"groovy","content":"repository.createNpmProxy('\''npm-proxy'\'', '\''https://registry.npmjs.org'\'')"}'

echo "Выполнение скрипта..."
curl -X POST -u "$ADMIN_USER:$ADMIN_PASS" \
  --header "Content-Type: text/plain" \
  "$NEXUS_URL/service/rest/v1/script/npm-proxy-setup/run"

echo "Готово."