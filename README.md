# Whisper on AWS SageMaker

Deploy OpenAI's Whisper Large V3 Turbo model to AWS SageMaker.

## Quick Start

All development happens in Docker containers to keep your system clean.

### 1. Download Model (First Time)

```bash
chmod +x scripts/*.sh
./scripts/docker-download-model.sh
```

### 2. Run Tests

```bash
./scripts/docker-test.sh
```

---

## Scripts

### `scripts/docker-download-model.sh`

Downloads the Whisper model (~3GB) inside a Docker container.

**What it does:**
- Builds Docker image
- Downloads model from HuggingFace
- Saves to `ml-model/whisper/model/`

**Usage:**
```bash
./scripts/docker-download-model.sh
```

**When to use:** First time setup, or to re-download the model.

---

### `scripts/docker-test.sh`

Runs SageMaker inference tests in a Docker container.

**What it does:**
- Builds test Docker image
- Runs `test_inference.py`
- Tests all SageMaker functions (model_fn, input_fn, predict_fn, output_fn)

**Usage:**
```bash
./scripts/docker-test.sh
```

**When to use:** After downloading model, or after code changes.

**Expected output:**
```
✓ model_fn() succeeded
✓ input_fn() with JSON succeeded
✓ predict_fn() succeeded
✓ output_fn() with JSON succeeded
✓ ALL TESTS PASSED
```

---

### `scripts/docker-dev.sh`

Opens an interactive development shell in a Docker container.

**What it does:**
- Builds development Docker image
- Starts bash shell with Python environment
- Mounts code directories as volumes

**Usage:**
```bash
./scripts/docker-dev.sh
```

**Inside the container:**
```bash
# View model files
ls /opt/ml/model/

# Run tests manually
python scripts/test_inference.py

# Exit
exit
```

**When to use:** For debugging or manual testing.

---

## Running Docker Containers

### Using Helper Scripts (Recommended)

```bash
# Download model
./scripts/docker-download-model.sh

# Run tests
./scripts/docker-test.sh

# Development shell
./scripts/docker-dev.sh
```

### Using Docker Compose Directly

```bash
# Run tests
docker-compose run --rm ml-test

# Start dev shell
docker-compose run --rm ml-dev bash

# Start inference server (SageMaker-like)
docker-compose up ml-inference
```

### Docker Compose Services

**`ml-dev`** - Development environment
- Interactive bash shell
- All dev tools included (ipython, pytest, black)

**`ml-test`** - Test runner
- Runs `test_inference.py` automatically
- Validates SageMaker inference pipeline

**`ml-inference`** - SageMaker-like server
- Listens on port 8080
- Simulates production deployment

---

## Dockerfile Stages

The `ml-model/Dockerfile` uses multi-stage builds:

**`base`** - Core dependencies
- Python 3.11 + system libraries
- ML packages (transformers, torch)

**`development`** - Dev tools
- Inherits from base
- Adds ipython, jupyter, pytest, black, flake8

**`sagemaker`** - Production image
- Minimal image for deployment
- Only inference code + model

Build specific stage:
```bash
docker build --target development -t whisper-dev ml-model/
docker build --target sagemaker -t whisper-inference ml-model/
```

---

## Troubleshooting

**Docker not running:**
```bash
docker info  # Check status
# Start Docker Desktop if needed
```

**Permission denied:**
```bash
chmod +x scripts/*.sh
```

**Model not found:**
```bash
./scripts/docker-download-model.sh
```

**Clean up Docker:**
```bash
docker-compose down          # Stop containers
docker system prune -a       # Clean up resources
```

---

## What's Git-Ignored

These are generated in containers and not committed:
- `ml-model/whisper/model/` - Model files (~3GB)
- `ml-model/venv/` - Virtual environments
- `ml-model/output/` - Generated files

---

## Project Details

See [PROJECT_PLAN.md](PROJECT_PLAN.md) for full project roadmap.
