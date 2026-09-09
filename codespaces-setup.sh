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

# 3. Stop any existing conflicting standalone containers
echo "==> Stopping any previous containers..."
docker compose -f docker-compose.standalone.yaml down 2>/dev/null || true

# 4. Start all Docker services using clean Codespaces compose (Port 80 HTTP)
echo "==> Starting WorkAdventure services via docker-compose.codespaces.yaml..."
docker compose -f docker-compose.codespaces.yaml up -d --force-recreate

echo ""
echo "==> Waiting for services to initialize..."
sleep 5

# Quick verification test
echo "==> Testing local Traefik routing..."
curl -s -o /dev/null -w "HTTP Response Code: %{http_code}\n" http://localhost || true

echo ""
echo "================================================================================"
if [ -n "$CODESPACE_NAME" ]; then
  echo "  SUCCESS! WorkAdventure is live on Codespaces!"
  echo ""
  echo "  Your Public URL:"
  echo "  https://${CODESPACE_NAME}-80.app.github.dev"
  echo ""
  echo "  NOTE: In the VS Code 'PORTS' tab (bottom panel), verify Port 80 visibility"
  echo "        is set to 'Public'. If it says 'Private', right-click -> Port Visibility -> Public."
else
  echo "  SUCCESS! WorkAdventure is running on http://localhost"
fi
echo "================================================================================"
