#!/bin/bash
# Script to start an interactive development shell in Docker

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Whisper ML Development Shell${NC}"
echo -e "${GREEN}================================${NC}"

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}✗ Docker is not running. Please start Docker first.${NC}"
    exit 1
fi

echo -e "\n${YELLOW}Building Docker image...${NC}"
docker-compose build ml-dev

echo -e "\n${YELLOW}Starting development container...${NC}"
echo -e "${GREEN}You can now run:${NC}"
echo -e "  - ${YELLOW}python scripts/test_inference.py${NC} - Test inference pipeline"
echo -e "  - ${YELLOW}python scripts/benchmark_model.py${NC} - Run benchmarks"
echo -e "  - ${YELLOW}python scripts/download_model.py${NC} - Download model"
echo -e ""

docker-compose run --rm ml-dev
