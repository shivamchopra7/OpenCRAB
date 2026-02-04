FROM node:22-bookworm AS builder

# OpenCRAB - Personal AI Assistant
# Product owned by illusionart AI Private Limited | Built by Shivam Chopra

# Build arguments with backward compatibility
ARG OPENCLAW_DOCKER_APT_PACKAGES=""
ARG OPENCRAB_DOCKER_APT_PACKAGES="${OPENCLAW_DOCKER_APT_PACKAGES:-}"

# Install additional apt packages if specified
RUN if [ -n "${OPENCRAB_DOCKER_APT_PACKAGES}${OPENCLAW_DOCKER_APT_PACKAGES}" ]; then \
  apt-get update && apt-get install -y --no-install-recommends \
  ${OPENCRAB_DOCKER_APT_PACKAGES} ${OPENCLAW_DOCKER_APT_PACKAGES} \
  && rm -rf /var/lib/apt/lists/*; \
  fi

# Install Bun for faster TypeScript execution
RUN npm install -g bun@latest

# Install pnpm
RUN corepack enable && corepack prepare pnpm@latest --activate

WORKDIR /app

# Copy package files first for better layer caching
COPY package.json pnpm-lock.yaml ./
COPY patches/ patches/

# Install dependencies
RUN pnpm install --frozen-lockfile

# Copy source code
COPY . .

# Build the project (supports both OPENCRAB_ and OPENCLAW_ env vars)
RUN OPENCRAB_A2UI_SKIP_MISSING=1 OPENCLAW_A2UI_SKIP_MISSING=1 pnpm build

# Build UI assets for Control UI
RUN CI=true pnpm ui:build

# Production stage
FROM node:22-bookworm-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
  ca-certificates \
  curl \
  git \
  && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd --create-home --shell /bin/bash node 2>/dev/null || true

WORKDIR /app

# Copy built files from builder
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./
COPY --from=builder /app/opencrab.mjs ./
COPY --from=builder /app/skills ./skills
COPY --from=builder /app/assets ./assets
COPY --from=builder /app/docs/reference/templates ./docs/reference/templates

# Create config directory
RUN mkdir -p /home/node/.opencrab && chown -R node:node /home/node

# Switch to non-root user
USER node

# Environment variables with backward compatibility
ENV OPENCRAB_PREFER_PNPM=1
ENV OPENCLAW_PREFER_PNPM=1
ENV HOME=/home/node

# Expose gateway port
EXPOSE 18789

# Default command - runs the gateway
CMD ["node", "dist/index.js", "gateway", "--bind", "lan"]
