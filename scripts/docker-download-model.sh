#!/bin/bash
# Script to download Whisper model in Docker container
# This keeps the host filesystem clean

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Download Whisper Model in Container${NC}"
echo -e "${GREEN}========================================${NC}"

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}✗ Docker is not running. Please start Docker first.${NC}"
    exit 1
fi

# Check if model already exists
if [ -f "ml-model/whisper/model/model.safetensors" ]; then
    echo -e "${YELLOW}⚠ Model already exists at ml-model/whisper/model/${NC}"
    read -p "Do you want to re-download? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}✓ Using existing model${NC}"
        exit 0
    fi
fi

echo -e "\n${YELLOW}Building Docker image...${NC}"
docker-compose build ml-dev

echo -e "\n${YELLOW}Creating model directory...${NC}"
mkdir -p ml-model/whisper/model

echo -e "\n${YELLOW}Downloading model in container...${NC}"
echo -e "${YELLOW}This may take several minutes (model is ~3GB)${NC}"

# Run download script in container with model directory mounted
docker-compose run --rm \
    -v "$(pwd)/ml-model/whisper/model:/opt/ml/model:rw" \
    ml-dev \
    python -c "
import sys
sys.path.insert(0, '/opt/ml/scripts')
from download_model import download_model
download_model(model_name='openai/whisper-large-v3-turbo', save_dir='/opt/ml/model')
"

echo -e "\n${GREEN}✓ Model downloaded successfully!${NC}"
echo -e "${YELLOW}Model location: ml-model/whisper/model/${NC}"
