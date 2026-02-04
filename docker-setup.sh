#!/usr/bin/env bash
# OpenCRAB Docker Setup Script
# Product owned by illusionart AI Private Limited | Built by Shivam Chopra
#
# This script builds the Docker image, runs the onboarding process interactively,
# and starts the gateway container.
#
# Environment variables (all optional, with sensible defaults):
#   OPENCRAB_IMAGE      - Docker image name (default: opencrab:local)
#   OPENCRAB_CONFIG_DIR - Config directory to mount (default: ~/.opencrab)
#   OPENCRAB_WORKSPACE_DIR - Workspace directory (default: ~/.opencrab/workspace)
#   OPENCRAB_GATEWAY_PORT - Gateway port (default: 18789)
#   OPENCRAB_BRIDGE_PORT - Bridge port (default: 18790)
#   OPENCRAB_GATEWAY_BIND - Gateway bind mode (default: lan)
#   OPENCRAB_DOCKER_APT_PACKAGES - Additional apt packages to install in the image
#
# Backward compatibility: OPENCLAW_* variables are also supported

set -euo pipefail

# Load .env if it exists
if [[ -f .env ]]; then
  source .env
fi

# Use OPENCRAB_ variables, falling back to OPENCLAW_ for backward compatibility
IMAGE_NAME="${OPENCRAB_IMAGE:-${OPENCLAW_IMAGE:-opencrab:local}}"
COMPOSE_PROJECT="${OPENCRAB_COMPOSE_PROJECT:-opencrab}"

# Resolve config and workspace directories
OPENCRAB_CONFIG_DIR="${OPENCRAB_CONFIG_DIR:-${OPENCLAW_CONFIG_DIR:-${HOME}/.opencrab}}"
OPENCRAB_WORKSPACE_DIR="${OPENCRAB_WORKSPACE_DIR:-${OPENCLAW_WORKSPACE_DIR:-${OPENCRAB_CONFIG_DIR}/workspace}}"

# Gateway settings
export OPENCRAB_GATEWAY_PORT="${OPENCRAB_GATEWAY_PORT:-${OPENCLAW_GATEWAY_PORT:-18789}}"
export OPENCRAB_BRIDGE_PORT="${OPENCRAB_BRIDGE_PORT:-${OPENCLAW_BRIDGE_PORT:-18790}}"
export OPENCRAB_GATEWAY_BIND="${OPENCRAB_GATEWAY_BIND:-${OPENCLAW_GATEWAY_BIND:-lan}}"

# Docker build arguments
APT_PACKAGES="${OPENCRAB_DOCKER_APT_PACKAGES:-${OPENCLAW_DOCKER_APT_PACKAGES:-}}"

# Extra mounts
EXTRA_MOUNTS="${OPENCRAB_EXTRA_MOUNTS:-${OPENCLAW_EXTRA_MOUNTS:-}}"

# Home volume for persistent node home
HOME_VOLUME_NAME="${OPENCRAB_HOME_VOLUME:-${OPENCLAW_HOME_VOLUME:-opencrab-home}}"

# Compose file args
COMPOSE_ARGS=(-p "$COMPOSE_PROJECT")
if [[ -f "docker-compose.yml" ]]; then
  COMPOSE_ARGS+=(-f "docker-compose.yml")
fi

echo "========================================"
echo " OpenCRAB Docker Setup"
echo " Product Owner: illusionart AI Private Limited"
echo " Built by: Shivam Chopra"
echo "========================================"
echo ""

# Check for Docker
if ! command -v docker &> /dev/null; then
  echo "Error: Docker is not installed or not in PATH."
  echo "Please install Docker: https://docs.docker.com/get-docker/"
  exit 1
fi

# Check for Docker Compose
if ! docker compose version &> /dev/null; then
  echo "Error: Docker Compose is not available."
  echo "Please install Docker Compose: https://docs.docker.com/compose/install/"
  exit 1
fi

# Create config directory if it doesn't exist
echo "==> Creating config directory: $OPENCRAB_CONFIG_DIR"
mkdir -p "$OPENCRAB_CONFIG_DIR"
mkdir -p "$OPENCRAB_WORKSPACE_DIR"

# Generate gateway token if not set
if [[ -z "${OPENCRAB_GATEWAY_TOKEN:-${OPENCLAW_GATEWAY_TOKEN:-}}" ]]; then
  OPENCRAB_GATEWAY_TOKEN=$(openssl rand -hex 16 2>/dev/null || head -c 32 /dev/urandom | xxd -p | head -c 32)
  echo "==> Generated gateway token: $OPENCRAB_GATEWAY_TOKEN"
  # Persist to .env to prevent token rotation on every run
  echo "OPENCRAB_GATEWAY_TOKEN=$OPENCRAB_GATEWAY_TOKEN" >> .env
  echo "OPENCLAW_GATEWAY_TOKEN=$OPENCRAB_GATEWAY_TOKEN" >> .env
fi
export OPENCRAB_GATEWAY_TOKEN="${OPENCRAB_GATEWAY_TOKEN:-${OPENCLAW_GATEWAY_TOKEN}}"

# Export for docker-compose
export OPENCRAB_CONFIG_DIR
export OPENCRAB_WORKSPACE_DIR
export OPENCRAB_IMAGE="$IMAGE_NAME"
export OPENCRAB_DOCKER_APT_PACKAGES="${APT_PACKAGES}"
export OPENCRAB_EXTRA_MOUNTS="$EXTRA_MOUNTS"
export OPENCRAB_HOME_VOLUME="$HOME_VOLUME_NAME"

# Build the Docker image
echo ""
echo "==> Building Docker image: $IMAGE_NAME"
BUILD_ARGS=()
if [[ -n "$APT_PACKAGES" ]]; then
  BUILD_ARGS+=(--build-arg "OPENCRAB_DOCKER_APT_PACKAGES=$APT_PACKAGES")
fi

docker build ${BUILD_ARGS[@]+"${BUILD_ARGS[@]}"} -t "$IMAGE_NAME" .

# Run onboarding interactively
echo ""
echo "==> Onboarding (interactive)"
echo "When prompted:"
echo "  - Gateway bind: lan"
echo "  - Gateway auth: token"
echo "  - Gateway token: $OPENCRAB_GATEWAY_TOKEN"
echo "  - Tailscale exposure: Off"
echo "  - Install Gateway daemon: No"
echo ""
docker compose "${COMPOSE_ARGS[@]}" run --rm opencrab-cli onboard --no-install-daemon

# Check for provider setup
echo ""
echo "==> Checking for messaging providers..."

# WhatsApp pairing
if [[ "${SETUP_WHATSAPP:-}" == "1" ]]; then
  echo ""
  echo "==> Setting up WhatsApp..."
  docker compose "${COMPOSE_ARGS[@]}" run --rm opencrab-cli channels login
fi

# Telegram setup
if [[ -n "${TELEGRAM_BOT_TOKEN:-}" ]]; then
  echo ""
  echo "==> Telegram bot token detected, will be used automatically."
fi

# Discord setup
if [[ -n "${DISCORD_BOT_TOKEN:-}" ]]; then
  echo ""
  echo "==> Discord bot token detected, will be used automatically."
fi

# Start the gateway
echo ""
echo "==> Starting OpenCRAB Gateway..."
docker compose "${COMPOSE_ARGS[@]}" up -d opencrab-gateway

# Show status
echo ""
echo "==> Gateway status:"
docker compose "${COMPOSE_ARGS[@]}" ps

# Show connection info
echo ""
echo "========================================"
echo " OpenCRAB is now running!"
echo "========================================"
echo ""
echo " Gateway URL: http://localhost:${OPENCRAB_GATEWAY_PORT}"
echo " Bridge Port: ${OPENCRAB_BRIDGE_PORT}"
echo " Config Dir:  ${OPENCRAB_CONFIG_DIR}"
echo ""
echo " Gateway Token: ${OPENCRAB_GATEWAY_TOKEN}"
echo ""
echo " To view logs:   docker compose -p $COMPOSE_PROJECT logs -f"
echo " To stop:        docker compose -p $COMPOSE_PROJECT down"
echo " To use CLI:     docker compose -p $COMPOSE_PROJECT --profile cli run --rm opencrab-cli"
echo ""
echo " Documentation: https://illusionart.ai"
echo ""
