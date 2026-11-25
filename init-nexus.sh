#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/.env" ]; then
  set -a
  source "$SCRIPT_DIR/.env"
  set +a
fi

NEXUS_URL="${NEXUS_URL:-http://localhost:8081}"
ADMIN_USER="${ADMIN_USER:?ADMIN_USER не задан}"
ADMIN_PASS="${ADMIN_PASS:?ADMIN_PASS не задан}"

# --- Параметры публичного npm proxy ---
PUBLIC_PROXY_NAME="${PUBLIC_PROXY_NAME:-npm-proxy-public}"
PUBLIC_REMOTE_URL="${PUBLIC_REMOTE_URL:-https://registry.npmjs.org/}"

# --- Параметры PyPI ---
PYPI_PROXY_NAME="${PYPI_PROXY_NAME:-pypi-proxy}"
PYPI_REMOTE_URL="${PYPI_REMOTE_URL:-https://pypi.org/}"
PYPI_GROUP_NAME="${PYPI_GROUP_NAME:-pypi-group}"

# --- Имя npm group ---
GROUP_NAME="${GROUP_NAME:-npm-group}"

echo "Ожидание запуска Nexus..."
until curl -s -o /dev/null -w "%{http_code}" "$NEXUS_URL/service/rest/v1/status" | grep -q "200"; do
  sleep 5
  echo "Nexus ещё не готов..."
done
echo "Nexus запущен."

# ---------------------------------------------------------------
# 1. Публичный npm proxy через REST API
# ---------------------------------------------------------------
echo "Создание публичного npm proxy $PUBLIC_PROXY_NAME..."
curl -sS -X POST -u "$ADMIN_USER:$ADMIN_PASS" \
  --header 'Content-Type: application/json' \
  "$NEXUS_URL/service/rest/v1/repositories/npm/proxy" \
  -d "{
    \"name\": \"$PUBLIC_PROXY_NAME\",
    \"online\": true,
    \"storage\": {
      \"blobStoreName\": \"default\",
      \"strictContentTypeValidation\": true,
      \"writePolicy\": \"allow\"
    },
    \"proxy\": {
      \"remoteUrl\": \"$PUBLIC_REMOTE_URL\",
      \"contentMaxAge\": 1440,
      \"metadataMaxAge\": 1440
    },
    \"negativeCache\": { \"enabled\": true, \"timeToLive\": 1440 },
    \"httpClient\": { \"blocked\": false, \"autoBlock\": true }
  }" || echo "Публичный npm proxy уже существует или создан."

# ---------------------------------------------------------------
# 2. npm Group (только публичный proxy, приватные добавляются отдельно)
# ---------------------------------------------------------------
echo "Создание npm group $GROUP_NAME..."
curl -sS -X POST -u "$ADMIN_USER:$ADMIN_PASS" \
  --header 'Content-Type: application/json' \
  "$NEXUS_URL/service/rest/v1/repositories/npm/group" \
  -d "{
    \"name\": \"$GROUP_NAME\",
    \"online\": true,
    \"storage\": {
      \"blobStoreName\": \"default\",
      \"strictContentTypeValidation\": true
    },
    \"group\": { \"memberNames\": [\"$PUBLIC_PROXY_NAME\"] }
  }" || echo "npm group уже существует или создан."

# ---------------------------------------------------------------
# 3. PyPI Proxy через REST API (с обязательными полями)
# ---------------------------------------------------------------
echo "Создание PyPI proxy $PYPI_PROXY_NAME..."
curl -sS -X POST -u "$ADMIN_USER:$ADMIN_PASS" \
  --header 'Content-Type: application/json' \
  "$NEXUS_URL/service/rest/v1/repositories/pypi/proxy" \
  -d "{
    \"name\": \"$PYPI_PROXY_NAME\",
    \"online\": true,
    \"storage\": {
      \"blobStoreName\": \"default\",
      \"strictContentTypeValidation\": true,
      \"writePolicy\": \"allow\"
    },
    \"proxy\": {
      \"remoteUrl\": \"$PYPI_REMOTE_URL\",
      \"contentMaxAge\": 1440,
      \"metadataMaxAge\": 1440
    },
    \"negativeCache\": { \"enabled\": true, \"timeToLive\": 1440 },
    \"httpClient\": { \"blocked\": false, \"autoBlock\": true }
  }" || echo "PyPI proxy уже существует или создан."

# ---------------------------------------------------------------
# 4. PyPI Group через REST API (с обязательными полями)
# ---------------------------------------------------------------
echo "Создание PyPI group $PYPI_GROUP_NAME..."
curl -sS -X POST -u "$ADMIN_USER:$ADMIN_PASS" \
  --header 'Content-Type: application/json' \
  "$NEXUS_URL/service/rest/v1/repositories/pypi/group" \
  -d "{
    \"name\": \"$PYPI_GROUP_NAME\",
    \"online\": true,
    \"storage\": {
      \"blobStoreName\": \"default\",
      \"strictContentTypeValidation\": true
    },
    \"group\": { \"memberNames\": [\"$PYPI_PROXY_NAME\"] }
  }" || echo "PyPI group уже существует или создан."

echo "Готово."
echo "npm registry URL: $NEXUS_URL/repository/$GROUP_NAME/"
echo "PyPI index URL:   $NEXUS_URL/repository/$PYPI_GROUP_NAME/simple/"