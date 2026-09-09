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

# 3. Start all Docker services
echo "==> Starting WorkAdventure services..."
docker compose -f docker-compose.standalone.yaml -f docker-compose.local.yaml up -d

echo ""
echo "================================================================================"
if [ -n "$CODESPACE_NAME" ]; then
  echo "  SUCCESS! WorkAdventure is live on Codespaces!"
  echo ""
  echo "  Your Public URL:"
  echo "  https://${CODESPACE_NAME}-80.app.github.dev"
  echo ""
  echo "  NOTE: In the 'Ports' tab, make sure Port 80 visibility is set to 'Public'."
else
  echo "  SUCCESS! WorkAdventure is running on http://localhost"
fi
echo "================================================================================"
