# ============================================================================
# HELM - Holistic Evaluation of Language Models
# Multi-stage Dockerfile for production deployment
# ============================================================================

# ---------- Stage 1: Frontend build ----------
FROM node:20-alpine AS frontend-build

WORKDIR /app/helm-frontend
COPY helm-frontend/package.json helm-frontend/yarn.lock ./
RUN yarn install --frozen-lockfile --network-timeout 120000

COPY helm-frontend/ ./
RUN yarn build

# ---------- Stage 2: Python backend ----------
FROM python:3.11-slim AS backend

# System deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Install uv for fast dependency management
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

# Set up app
WORKDIR /app
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    UV_COMPILE_BYTECODE=1 \
    HELM_OUTPUT_DIR=/data/benchmark_output \
    HELM_CACHE_DIR=/data/cache \
    HELM_SUITE=default

# Copy project files
COPY pyproject.toml uv.lock requirements.txt constraints.txt MANIFEST.in ./
COPY src/ src/
COPY conftest.py ./

# Install dependencies
RUN uv sync --no-dev --frozen 2>/dev/null || uv pip install --system -r requirements.txt

# Copy frontend build artifacts
COPY --from=frontend-build /app/helm-frontend/dist /app/helm-frontend/dist

# Copy remaining project files
COPY scripts/ scripts/
COPY docs/ docs/
COPY .env.example ./

# Create directories for data persistence
RUN mkdir -p /data/benchmark_output /data/cache /data/logs

# Default port for helm-server
EXPOSE 8000
# Default port for proxy server
EXPOSE 1959

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8000/ || exit 1

# Default: run the benchmark web server
CMD ["uv", "run", "helm-server", "--port", "8000", "--suite", "${HELM_SUITE}", "--output-path", "${HELM_OUTPUT_DIR}"]
