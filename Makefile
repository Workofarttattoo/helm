# ============================================================================
# HELM - Makefile
# ============================================================================
# Usage: make <target>
#
# Targets:
#   up         Start all services
#   down       Stop all services
#   build      Build Docker images
#   test       Run test suite
#   lint       Run linters (flake8, mypy, black --check)
#   format     Auto-format code with black
#   clean      Remove build artifacts, caches, temp files
#   logs       Tail Docker service logs
#   shell      Open shell in helm-server container
#   run        Execute a benchmark run (use RUN_ARGS=)
#   summarize  Summarize benchmark results
#   install    Install for local development
#   help       Show this help
# ============================================================================

.DEFAULT_GOAL := help
.PHONY: help up down build test lint format clean logs shell run summarize install

DOCKER_COMPOSE := docker compose
SUITE          ?= default
RUN_ARGS       ?= --run-entries simple1:model=simple/model1 --max-eval-instances 10

# ---------- Docker ----------

up: ## Start all services (helm-server + helm-proxy)
	$(DOCKER_COMPOSE) up -d
	@echo "✓ HELM server running at http://localhost:$${HELM_SERVER_PORT:-8000}"
	@echo "✓ HELM proxy running at http://localhost:$${HELM_PROXY_PORT:-1959}"

down: ## Stop all services
	$(DOCKER_COMPOSE) down

build: ## Build Docker images
	$(DOCKER_COMPOSE) build

rebuild: ## Rebuild Docker images (no cache)
	$(DOCKER_COMPOSE) build --no-cache

logs: ## Tail service logs (use SVC= for specific service)
ifdef SVC
	$(DOCKER_COMPOSE) logs -f $(SVC)
else
	$(DOCKER_COMPOSE) logs -f
endif

shell: ## Open shell in helm-server container
	$(DOCKER_COMPOSE) exec helm-server /bin/bash

# ---------- Development ----------

install: ## Install for local development
	uv sync --extra all
	@echo "✓ Dependencies installed"
	@echo "Run: source .venv/bin/activate"

test: ## Run test suite
	uv run pytest --durations=20 -x -q

test-verbose: ## Run tests with verbose output
	uv run pytest --durations=20 -v

test-models: ## Run model tests (makes real API requests)
	uv run pytest -m models --durations=20

test-scenarios: ## Run scenario tests (downloads data)
	uv run pytest -m scenarios --durations=20

lint: ## Run linters
	uv run flake8 src/helm/
	uv run mypy src/helm/ --ignore-missing-imports
	uv run black --check src/helm/

format: ## Auto-format code with black
	uv run black src/helm/
	@echo "✓ Code formatted"

typecheck: ## Run mypy type checker
	uv run mypy src/helm/ --ignore-missing-imports

# ---------- Benchmarking ----------

run: ## Run benchmarks (set RUN_ARGS for custom runs)
	uv run helm-run $(RUN_ARGS) --suite $(SUITE)

summarize: ## Summarize benchmark results
	uv run helm-summarize --suite $(SUITE)

serve: ## Start local HELM results server
	uv run helm-server --suite $(SUITE)

proxy: ## Start local HELM proxy server
	uv run crfm-proxy-server

# ---------- Frontend ----------

frontend-install: ## Install frontend dependencies
	cd helm-frontend && yarn install

frontend-dev: ## Start frontend dev server
	cd helm-frontend && yarn dev

frontend-build: ## Build frontend for production
	cd helm-frontend && yarn build

frontend-lint: ## Lint frontend code
	cd helm-frontend && yarn lint:check && yarn format:check

# ---------- Cleanup ----------

clean: ## Remove build artifacts, caches, and temp files
	rm -rf build/ dist/ *.egg-info
	rm -rf .mypy_cache .pytest_cache
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete 2>/dev/null || true
	rm -rf benchmark_output/
	rm -rf helm-frontend/dist/
	@echo "✓ Cleaned"

clean-docker: ## Remove Docker images and volumes
	$(DOCKER_COMPOSE) down -v --rmi local
	@echo "✓ Docker artifacts removed"

clean-all: clean clean-docker ## Remove everything

# ---------- Help ----------

help: ## Show this help
	@echo "HELM - Holistic Evaluation of Language Models"
	@echo ""
	@echo "Usage: make <target>"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'
