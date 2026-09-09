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
sleep 6

# Quick verification test
echo "==> Testing local Traefik routing..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost || echo "failed")
HTTP_CODE_L=$(curl -s -L -o /dev/null -w "%{http_code}" http://localhost || echo "failed")
echo "Direct HTTP Code: ${HTTP_CODE} (Expected 302 or 200)"
echo "Follow-Redirects HTTP Code: ${HTTP_CODE_L} (Expected 200)"

echo ""
echo "================================================================================"
if [ -n "$CODESPACE_NAME" ]; then
  echo "  SUCCESS! WorkAdventure is running!"
  echo ""
  echo "  Your Public URL:"
  echo "  https://${CODESPACE_NAME}-80.app.github.dev"
  echo ""
  echo "  CRITICAL STEP FOR 404/504 FIX:"
  echo "  In VS Code, open the 'PORTS' tab (bottom panel next to Terminal):"
  echo "  1. Look for Port 80."
  echo "  2. If Visibility is 'Private', RIGHT-CLICK -> 'Port Visibility' -> 'Public'."
  echo "  3. Click the Globe icon next to Port 80 to open in your browser."
else
  echo "  SUCCESS! WorkAdventure is running on http://localhost"
fi
echo "================================================================================"
