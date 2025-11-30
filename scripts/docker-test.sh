#!/bin/bash
# Script to run ML model tests in Docker container

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Whisper Model Docker Testing${NC}"
echo -e "${GREEN}================================${NC}"

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}✗ Docker is not running. Please start Docker first.${NC}"
    exit 1
fi

echo -e "\n${YELLOW}Building Docker image...${NC}"
docker-compose build ml-test

echo -e "\n${YELLOW}Creating output directory...${NC}"
mkdir -p ml-model/output

echo -e "\n${YELLOW}Running tests in container...${NC}"
docker-compose run --rm ml-test

echo -e "\n${GREEN}✓ Tests completed!${NC}"
echo -e "${YELLOW}Check ml-model/output/ for any generated files${NC}"
