#!/usr/bin/env bash
# ============================================================================
# HELM Production Deployment Script
# ============================================================================
# Usage:
#   ./scripts/deploy.sh              # Deploy with defaults
#   ./scripts/deploy.sh --build      # Force rebuild images
#   ./scripts/deploy.sh --pull       # Pull latest code first
#   ./scripts/deploy.sh --migrate    # Run data migrations
# ============================================================================

set -euo pipefail

# ---------- Configuration ----------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
COMPOSE_FILE="${PROJECT_DIR}/docker-compose.yml"
ENV_FILE="${PROJECT_DIR}/.env"
LOG_FILE="${PROJECT_DIR}/deploy.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ---------- Helpers ----------
log() { echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*" | tee -a "$LOG_FILE"; }
success() { echo -e "${GREEN}✓${NC} $*" | tee -a "$LOG_FILE"; }
warn() { echo -e "${YELLOW}⚠${NC} $*" | tee -a "$LOG_FILE"; }
error() { echo -e "${RED}✗${NC} $*" | tee -a "$LOG_FILE"; exit 1; }

# ---------- Pre-flight checks ----------
preflight() {
    log "Running pre-flight checks..."

    # Docker
    command -v docker >/dev/null 2>&1 || error "Docker is not installed"
    docker info >/dev/null 2>&1 || error "Docker daemon is not running"

    # Docker Compose
    docker compose version >/dev/null 2>&1 || error "Docker Compose V2 is not installed"

    # Env file
    if [[ ! -f "$ENV_FILE" ]]; then
        warn ".env file not found - copying from .env.example"
        cp "${PROJECT_DIR}/.env.example" "$ENV_FILE"
        warn "Please edit .env with your API keys before running benchmarks"
    fi

    # Validate required env vars for production
    if [[ "${HELM_ENV:-development}" == "production" ]]; then
        source "$ENV_FILE"
        if [[ -z "${OPENAI_API_KEY:-}" && -z "${ANTHROPIC_API_KEY:-}" ]]; then
            warn "No model API keys configured. Set at least one in .env"
        fi
    fi

    success "Pre-flight checks passed"
}

# ---------- Deploy ----------
deploy() {
    local do_build=false
    local do_pull=false
    local do_migrate=false

    # Parse args
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --build)   do_build=true; shift ;;
            --pull)    do_pull=true; shift ;;
            --migrate) do_migrate=true; shift ;;
            --help)    usage; exit 0 ;;
            *)         error "Unknown option: $1" ;;
        esac
    done

    log "Starting HELM deployment..."

    # Pull latest code
    if [[ "$do_pull" == true ]]; then
        log "Pulling latest code..."
        cd "$PROJECT_DIR"
        git pull --rebase origin main
        success "Code updated"
    fi

    # Build images
    if [[ "$do_build" == true ]]; then
        log "Building Docker images..."
        docker compose -f "$COMPOSE_FILE" build --no-cache
        success "Images built"
    fi

    # Stop existing services
    log "Stopping existing services..."
    docker compose -f "$COMPOSE_FILE" down --timeout 30 2>/dev/null || true

    # Start services
    log "Starting services..."
    docker compose -f "$COMPOSE_FILE" up -d

    # Wait for health
    log "Waiting for services to be healthy..."
    local retries=0
    local max_retries=30
    while [[ $retries -lt $max_retries ]]; do
        if docker compose -f "$COMPOSE_FILE" ps --format json 2>/dev/null | grep -q '"Health":"healthy"'; then
            break
        fi
        sleep 2
        retries=$((retries + 1))
    done

    if [[ $retries -ge $max_retries ]]; then
        warn "Services may not be fully healthy yet. Check: docker compose logs"
    fi

    # Print status
    echo ""
    log "Deployment complete!"
    echo ""
    docker compose -f "$COMPOSE_FILE" ps
    echo ""
    success "HELM Server: http://localhost:${HELM_SERVER_PORT:-8000}"
    success "HELM Proxy:  http://localhost:${HELM_PROXY_PORT:-1959}"
    echo ""
}

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --build      Force rebuild Docker images"
    echo "  --pull       Pull latest code before deploying"
    echo "  --migrate    Run data migrations (future use)"
    echo "  --help       Show this help"
}

# ---------- Main ----------
preflight
deploy "$@"
