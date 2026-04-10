# Holistic Evaluation of Language Models (HELM)

<img src="https://github.com/stanford-crfm/helm/raw/v0.5.4/helm-frontend/src/assets/helm-logo.png" alt="HELM logo" width="480"/>

[![GitHub stars](https://img.shields.io/github/stars/stanford-crfm/helm)](https://github.com/stanford-crfm/helm)
[![License](https://img.shields.io/github/license/stanford-crfm/helm?color=blue)](LICENSE)
[![PyPI](https://img.shields.io/pypi/v/crfm-helm?color=blue)](https://pypi.org/project/crfm-helm/)
[![Docs](https://readthedocs.org/projects/helm/badge/?version=latest)](https://crfm-helm.readthedocs.io/)

**HELM** is an open-source Python framework created by [Stanford CRFM](https://crfm.stanford.edu/) for holistic, reproducible, and transparent evaluation of foundation models — including LLMs and multimodal models.

## Features

- **Standardized benchmarks** — MMLU-Pro, GPQA, IFEval, WildBench, and many more
- **Unified model interface** — OpenAI, Anthropic Claude, Google Gemini, Together AI, Cohere, and others
- **Comprehensive metrics** — Accuracy, efficiency, bias, toxicity, calibration
- **Web UI** — Inspect individual prompts, responses, and model outputs
- **Leaderboard** — Compare results across models and benchmarks

## Table of Contents

- [Quick Start](#quick-start)
- [Docker Deployment](#docker-deployment)
- [Local Development](#local-development)
- [CLI Reference](#cli-reference)
- [API & Architecture](#api--architecture)
- [Environment Variables](#environment-variables)
- [Frontend](#frontend)
- [Testing](#testing)
- [Deployment](#deployment)
- [Leaderboards](#leaderboards)
- [Papers](#papers)
- [Contributing](#contributing)
- [License](#license)

## Quick Start

### Install from PyPI

```bash
pip install crfm-helm
```

### Run a benchmark

```bash
# Evaluate GPT-2 on MMLU Philosophy (10 instances)
helm-run \
  --run-entries mmlu:subject=philosophy,model=openai/gpt2 \
  --suite my-suite \
  --max-eval-instances 10

# Summarize results
helm-summarize --suite my-suite

# Launch results UI
helm-server --suite my-suite
```

Open [http://localhost:8000](http://localhost:8000) in your browser.

## Docker Deployment

### Prerequisites

- Docker Engine 20.10+
- Docker Compose V2

### Setup

```bash
# 1. Clone the repo
git clone https://github.com/Workofarttattoo/helm.git
cd helm

# 2. Configure environment
cp .env.example .env
# Edit .env with your API keys

# 3. Start services
make up
```

This starts:
- **helm-server** on `http://localhost:8000` — Results UI
- **helm-proxy** on `http://localhost:1959` — API proxy server

### Run benchmarks in Docker

```bash
# Start a benchmark run
docker compose --profile run up helm-runner
```

### Manage services

```bash
make up          # Start services
make down        # Stop services
make logs        # Tail logs
make shell       # Shell into helm-server container
make build       # Rebuild images
make rebuild     # Rebuild images (no cache)
```

## Local Development

### Prerequisites

- Python 3.10+
- [uv](https://docs.astral.sh/uv/) (recommended) or pip
- Node.js 18+ and Yarn (for frontend)

### Setup

```bash
# Install with uv (recommended)
make install

# Or manually
uv sync --extra all

# Activate venv
source .venv/bin/activate
```

### Development workflow

```bash
make test        # Run tests
make lint        # Run flake8 + mypy + black --check
make format      # Auto-format with black
make serve       # Start local results server
make proxy       # Start local proxy server
```

## CLI Reference

### `helm-run` — Execute Benchmarks

```bash
helm-run \
  --run-entries <spec> \          # Benchmark specification
  --suite <name> \                # Suite name for results
  --max-eval-instances <n> \      # Limit evaluation instances
  --output-path <dir> \           # Output directory
  --num-threads <n> \             # Parallel execution threads
  --exit-on-error                 # Stop on first error
```

**Examples:**

```bash
# Single benchmark
helm-run --run-entries mmlu:subject=philosophy,model=openai/gpt-4 --suite eval-v1

# Multiple models
helm-run --run-entries mmlu:subject=math,model=openai/gpt-4 mmlu:subject=math,model=anthropic/claude-3-opus --suite compare

# Quick test (no data)
helm-run --suite test -m 100 --skip-instances --models-to-run openai/davinci
```

### `helm-summarize` — Summarize Results

```bash
helm-summarize --suite <name> [--output-path <dir>]
```

### `helm-server` — Results Web UI

```bash
helm-server --suite <name> [--port 8000] [--output-path <dir>]
```

### `crfm-proxy-server` — Model API Proxy

```bash
crfm-proxy-server [--port 1959] [--workers 4]
```

### `helm-create-plots` — Generate Plots

```bash
helm-create-plots --suite <name>
```

## API & Architecture

### Project Structure

```
helm/
├── src/helm/                    # Main Python package
│   ├── benchmark/               # Core benchmarking framework
│   │   ├── adaptation/          # Model adapters
│   │   ├── annotation/          # Annotation tools
│   │   ├── augmentations/       # Data augmentation
│   │   ├── metrics/             # Evaluation metrics
│   │   ├── presentation/        # Results summarization & UI
│   │   ├── run_specs/           # Benchmark run specifications
│   │   ├── scenarios/           # Benchmark scenarios/datasets
│   │   ├── static/              # Static configuration files
│   │   └── window_services/     # Tokenization window services
│   ├── clients/                 # Model provider clients
│   │   ├── audio_language/      # Audio-language model clients
│   │   ├── image_generation/    # Image generation clients
│   │   └── vision_language/     # Vision-language model clients
│   ├── common/                  # Shared utilities
│   ├── config/                  # Configuration management
│   ├── proxy/                   # API proxy server
│   │   ├── critique/            # Model critique tools
│   │   ├── services/            # Service layer
│   │   └── token_counters/      # Token counting utilities
│   └── tokenizers/              # Tokenizer implementations
├── helm-frontend/               # React/TypeScript frontend
├── scripts/                     # Utility & deployment scripts
├── docs/                        # Documentation (MkDocs)
├── Dockerfile                   # Production Docker image
├── docker-compose.yml           # Multi-service orchestration
├── Makefile                     # Development & operations commands
├── pyproject.toml               # Python project configuration
└── .env.example                 # Environment variable template
```

### Key Entry Points

| Command              | Module                                       | Description              |
|---------------------|----------------------------------------------|--------------------------|
| `helm-run`          | `helm.benchmark.run:main`                    | Execute benchmarks       |
| `helm-summarize`    | `helm.benchmark.presentation.summarize:main` | Summarize results        |
| `helm-server`       | `helm.benchmark.server:main`                 | Results web UI           |
| `helm-create-plots` | `helm.benchmark.presentation.create_plots:main` | Generate plots        |
| `crfm-proxy-server` | `helm.proxy.server:main`                     | Model API proxy          |

### Model Providers

HELM supports models through a unified client interface:

| Provider    | Models                    | Extra Dependencies |
|------------|---------------------------|--------------------|
| OpenAI     | GPT-4, GPT-3.5, etc.     | (included)         |
| Anthropic  | Claude 3, Claude 2       | `anthropic`        |
| Google     | Gemini, PaLM             | `google`           |
| Together   | Open-source models        | `together`         |
| Cohere     | Command, Embed            | `cohere`           |
| HuggingFace| Local/hosted models       | `huggingface`      |
| LiteLLM    | Unified multi-provider    | `litellm`          |

Install extras: `pip install crfm-helm[anthropic,google,together]`

## Environment Variables

| Variable               | Default                  | Description                        |
|-----------------------|--------------------------|------------------------------------|
| `HELM_SUITE`          | `default`                | Benchmark suite name               |
| `HELM_OUTPUT_DIR`     | `/data/benchmark_output` | Results output directory           |
| `HELM_CACHE_DIR`      | `/data/cache`            | Cache directory                    |
| `HELM_SERVER_PORT`    | `8000`                   | Results server port                |
| `HELM_PROXY_PORT`     | `1959`                   | Proxy server port                  |
| `HELM_PROXY_WORKERS`  | `4`                      | Proxy server worker count          |
| `OPENAI_API_KEY`      | —                        | OpenAI API key                     |
| `ANTHROPIC_API_KEY`   | —                        | Anthropic API key                  |
| `GOOGLE_API_KEY`      | —                        | Google API key                     |
| `TOGETHER_API_KEY`    | —                        | Together AI API key                |
| `COHERE_API_KEY`      | —                        | Cohere API key                     |
| `PERSPECTIVE_API_KEY` | —                        | Google Perspective API (toxicity)  |
| `LOG_LEVEL`           | `INFO`                   | Logging level                      |

See [`.env.example`](.env.example) for the full template.

## Frontend

The HELM frontend is a React/TypeScript application built with Vite:

```bash
# Install dependencies
cd helm-frontend && yarn install

# Development server (hot reload)
yarn dev

# Production build
yarn build

# Run lint & format checks
yarn lint:check && yarn format:check
```

The frontend is automatically built and served by `helm-server` in Docker.

## Testing

```bash
# Run unit tests (excludes model & scenario tests)
make test

# Run with verbose output
make test-verbose

# Run model tests (makes real API calls — requires API keys)
make test-models

# Run scenario tests (downloads datasets — slow)
make test-scenarios
```

Test configuration is in `pyproject.toml` under `[tool.pytest.ini_options]`.

## Deployment

### Production deployment

```bash
# Deploy with defaults
./scripts/deploy.sh

# Force rebuild + deploy
./scripts/deploy.sh --build

# Pull latest code + deploy
./scripts/deploy.sh --pull
```

The deploy script handles:
1. Pre-flight checks (Docker, env file, API keys)
2. Optional code pull and image rebuild
3. Graceful service restart
4. Health check verification

### Resource recommendations

| Component    | CPU   | RAM   | Storage |
|-------------|-------|-------|---------|
| helm-server | 1 CPU | 2 GB  | 10 GB   |
| helm-proxy  | 2 CPU | 4 GB  | 5 GB    |
| helm-runner | 4 CPU | 16 GB | 50 GB+  |

## Leaderboards

Official leaderboards maintained with HELM:

- [HELM Capabilities](https://crfm.stanford.edu/helm/capabilities/latest/)
- [HELM Safety](https://crfm.stanford.edu/helm/safety/latest/)
- [VHELM (Vision-Language)](https://crfm.stanford.edu/helm/vhelm/latest/)
- [MedHELM](https://crfm.stanford.edu/helm/medhelm/latest/)

Full list: [crfm.stanford.edu/helm](https://crfm.stanford.edu/helm/)

## Papers

- **Holistic Evaluation of Language Models** — [paper](https://openreview.net/forum?id=iO4LZibEqW), [leaderboard](https://crfm.stanford.edu/helm/classic/latest/)
- **VHELM** — [paper](https://arxiv.org/abs/2410.07112), [leaderboard](https://crfm.stanford.edu/helm/vhelm/latest/)
- **HEIM** — [paper](https://arxiv.org/abs/2311.04287), [leaderboard](https://crfm.stanford.edu/helm/heim/latest/)
- **MedHELM** — [leaderboard](https://crfm.stanford.edu/helm/medhelm/latest/)

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Install dev dependencies: `make install`
4. Make your changes
5. Run checks: `make lint && make test`
6. Commit: `git commit -m "feat: add my feature"`
7. Push & create a Pull Request

### Code style

- Python: [Black](https://black.readthedocs.io/) (line length 120), [Flake8](https://flake8.pycqa.org/), [mypy](https://mypy-lang.org/)
- TypeScript: ESLint + Prettier
- Pre-commit hooks: `pre-commit install`

## License

Apache License 2.0 — see [LICENSE](LICENSE).

## Citation

```bibtex
@article{liang2023holistic,
  title={Holistic Evaluation of Language Models},
  author={Percy Liang and Rishi Bommasani and Tony Lee and Dimitris Tsipras and others},
  journal={Transactions on Machine Learning Research},
  year={2023}
}
```

---

*Originally developed by [Stanford CRFM](https://crfm.stanford.edu/). Maintained by the Workofarttattoo team.*
