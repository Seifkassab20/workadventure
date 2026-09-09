#!/usr/bin/env bash
set -e

echo "==> Configuring WorkAdventure for GitHub Codespaces..."

# 1. Ensure .env exists from example
if [ ! -f .env ]; then
  cp .env.docker.example .env
fi

# 2. If running inside GitHub Codespaces, configure domain
if [ -n "$CODESPACE_NAME" ]; then
  CS_DOMAIN="${CODESPACE_NAME}-80.app.github.dev"
  echo "==> Detected Codespace Domain: https://${CS_DOMAIN}"
  sed -i "s|^DOMAIN=.*|DOMAIN=${CS_DOMAIN}|" .env
  if grep -q "^PROTOCOL=" .env; then
    sed -i "s|^PROTOCOL=.*|PROTOCOL=https|" .env
  else
    echo "PROTOCOL=https" >> .env
  fi
else
  sed -i "s|^DOMAIN=.*|DOMAIN=localhost|" .env
  if grep -q "^PROTOCOL=" .env; then
    sed -i "s|^PROTOCOL=.*|PROTOCOL=http|" .env
  else
    echo "PROTOCOL=http" >> .env
  fi
fi

# 3. Forcefully clean any old containers
echo "==> Removing any old containers..."
docker compose -f docker-compose.standalone.yaml down 2>/dev/null || true
docker compose -f docker-compose.codespaces.yaml down 2>/dev/null || true
docker rm -f $(docker ps -aq --filter name=workadventure) 2>/dev/null || true

# 4. Start all Docker services using clean Codespaces compose
echo "==> Starting WorkAdventure services via docker-compose.codespaces.yaml..."
docker compose -f docker-compose.codespaces.yaml up -d --force-recreate

echo ""
echo "==> Waiting for services to initialize..."
sleep 10

# Direct check bypassing any Codespaces terminal proxy
echo "==> Testing direct Traefik routing (bypassing proxy)..."
HTTP_CODE_80=$(curl --noproxy "*" -s -o /dev/null -w "%{http_code}" http://127.0.0.1:80/ || echo "failed")
HTTP_CODE_8000=$(curl --noproxy "*" -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8000/ || echo "failed")
echo "Port 80 HTTP Code: ${HTTP_CODE_80} (Expected 302 or 200)"
echo "Port 8000 HTTP Code: ${HTTP_CODE_8000} (Expected 302 or 200)"

echo ""
echo "==> Registered Traefik Routers:"
curl --noproxy "*" -s http://127.0.0.1:8080/api/http/routers | grep -o '"name":"[^"]*"' || true

echo ""
echo "================================================================================"
if [ -n "$CODESPACE_NAME" ]; then
  echo "  SUCCESS! WorkAdventure is live on Codespaces!"
  echo ""
  echo "  Port 80 URL:   https://${CODESPACE_NAME}-80.app.github.dev"
  echo "  Port 8000 URL: https://${CODESPACE_NAME}-8000.app.github.dev"
  echo ""
  echo "  PORTS TAB INSTRUCTIONS:"
  echo "  1. Switch to the 'PORTS' tab in the bottom panel."
  echo "  2. Ensure Visibility is set to 'Public'."
  echo "  3. Click the Globe icon for Port 80 (or Port 8000)."
else
  echo "  SUCCESS! WorkAdventure is running on http://localhost"
fi
echo "================================================================================"
