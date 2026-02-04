#!/usr/bin/env bash
# OpenCRAB - One-Click Docker Start
# Product owned by illusionart AI Private Limited | Built by Shivam Chopra
#
# This is the simplest way to run OpenCRAB.
# For guided setup with onboarding, use ./docker-setup.sh instead.
#
# Usage:
#   ./docker-start.sh          # Build and start
#   ./docker-start.sh --build  # Force rebuild before starting
#   ./docker-start.sh --stop   # Stop the gateway
#   ./docker-start.sh --logs   # View gateway logs

set -euo pipefail

# Configuration with backward compatibility
OPENCRAB_IMAGE="${OPENCRAB_IMAGE:-${OPENCLAW_IMAGE:-opencrab:local}}"
COMPOSE_PROJECT="${OPENCRAB_COMPOSE_PROJECT:-opencrab}"

# Parse arguments
ACTION="start"
BUILD_FLAG=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --build)
      BUILD_FLAG="--build"
      shift
      ;;
    --stop)
      ACTION="stop"
      shift
      ;;
    --logs)
      ACTION="logs"
      shift
      ;;
    --help|-h)
      echo "OpenCRAB One-Click Docker Start"
      echo ""
      echo "Usage:"
      echo "  ./docker-start.sh          # Build and start"
      echo "  ./docker-start.sh --build  # Force rebuild before starting"
      echo "  ./docker-start.sh --stop   # Stop the gateway"
      echo "  ./docker-start.sh --logs   # View gateway logs"
      echo ""
      echo "Environment Variables:"
      echo "  OPENCRAB_IMAGE            Docker image name (default: opencrab:local)"
      echo "  OPENCRAB_CONFIG_DIR       Config directory (default: ~/.opencrab)"
      echo "  OPENCRAB_GATEWAY_TOKEN    Gateway authentication token"
      echo ""
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Setup default directories
export OPENCRAB_CONFIG_DIR="${OPENCRAB_CONFIG_DIR:-${OPENCLAW_CONFIG_DIR:-${HOME}/.opencrab}}"
export OPENCRAB_WORKSPACE_DIR="${OPENCRAB_WORKSPACE_DIR:-${OPENCLAW_WORKSPACE_DIR:-${OPENCRAB_CONFIG_DIR}/workspace}}"
export OPENCRAB_GATEWAY_PORT="${OPENCRAB_GATEWAY_PORT:-${OPENCLAW_GATEWAY_PORT:-18789}}"
export OPENCRAB_BRIDGE_PORT="${OPENCRAB_BRIDGE_PORT:-${OPENCLAW_BRIDGE_PORT:-18790}}"
export OPENCRAB_GATEWAY_BIND="${OPENCRAB_GATEWAY_BIND:-${OPENCLAW_GATEWAY_BIND:-lan}}"
export OPENCRAB_IMAGE="${OPENCRAB_IMAGE}"

# Generate token if not set
if [[ -z "${OPENCRAB_GATEWAY_TOKEN:-${OPENCLAW_GATEWAY_TOKEN:-}}" ]]; then
  export OPENCRAB_GATEWAY_TOKEN=$(openssl rand -hex 16 2>/dev/null || head -c 32 /dev/urandom | xxd -p | head -c 32)
else
  export OPENCRAB_GATEWAY_TOKEN="${OPENCRAB_GATEWAY_TOKEN:-${OPENCLAW_GATEWAY_TOKEN}}"
fi

# Create .env file if it doesn't exist (ensures docker compose picks up variables)
if [[ ! -f .env ]]; then
  echo "==> Generating .env file..."
  cat > .env <<EOF
OPENCRAB_IMAGE=${OPENCRAB_IMAGE}
OPENCRAB_CONFIG_DIR=${OPENCRAB_CONFIG_DIR}
OPENCRAB_WORKSPACE_DIR=${OPENCRAB_WORKSPACE_DIR}
OPENCRAB_GATEWAY_PORT=${OPENCRAB_GATEWAY_PORT}
OPENCRAB_BRIDGE_PORT=${OPENCRAB_BRIDGE_PORT}
OPENCRAB_GATEWAY_BIND=${OPENCRAB_GATEWAY_BIND}
OPENCRAB_GATEWAY_TOKEN=${OPENCRAB_GATEWAY_TOKEN}
# Backward compatibility
OPENCLAW_IMAGE=${OPENCRAB_IMAGE}
OPENCLAW_CONFIG_DIR=${OPENCRAB_CONFIG_DIR}
OPENCLAW_WORKSPACE_DIR=${OPENCRAB_WORKSPACE_DIR}
OPENCLAW_GATEWAY_TOKEN=${OPENCRAB_GATEWAY_TOKEN}
EOF
fi

echo "🦀 OpenCRAB One-Click Start"
echo ""

case $ACTION in
  start)
    # Create directories
    mkdir -p "$OPENCRAB_CONFIG_DIR"
    mkdir -p "$OPENCRAB_WORKSPACE_DIR"
    
    # Build if needed or requested
    if [[ -n "$BUILD_FLAG" ]] || ! docker image inspect "$OPENCRAB_IMAGE" &>/dev/null; then
      echo "==> Building Docker image: $OPENCRAB_IMAGE"
      docker build -t "$OPENCRAB_IMAGE" .
    fi
    
    echo "==> Starting OpenCRAB Gateway..."
    docker compose -p "$COMPOSE_PROJECT" up -d opencrab-gateway
    
    echo ""
    echo "✅ OpenCRAB is running!"
    echo ""
    echo "   Gateway: http://localhost:${OPENCRAB_GATEWAY_PORT}"
    echo "   Token:   ${OPENCRAB_GATEWAY_TOKEN}"
    echo ""
    echo "   Logs:    ./docker-start.sh --logs"
    echo "   Stop:    ./docker-start.sh --stop"
    ;;
    
  stop)
    echo "==> Stopping OpenCRAB..."
    docker compose -p "$COMPOSE_PROJECT" down
    echo "✅ OpenCRAB stopped."
    ;;
    
  logs)
    docker compose -p "$COMPOSE_PROJECT" logs -f opencrab-gateway
    ;;
esac
