#!/bin/bash
# Script to package Whisper model for SageMaker deployment
# Creates model.tar.gz with model files, inference code, and requirements

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Package Model for SageMaker${NC}"
echo -e "${GREEN}========================================${NC}"

# Check if model exists
if [ ! -f "ml-model/whisper/model/model.safetensors" ]; then
    echo -e "${RED}✗ Model not found at ml-model/whisper/model/${NC}"
    echo -e "${YELLOW}Run ./scripts/docker-download-model.sh first${NC}"
    exit 1
fi

# Check if inference.py exists
if [ ! -f "ml-model/whisper/inference.py" ]; then
    echo -e "${RED}✗ inference.py not found at ml-model/whisper/${NC}"
    exit 1
fi

# Check if requirements.txt exists
if [ ! -f "ml-model/whisper/requirements.txt" ]; then
    echo -e "${RED}✗ requirements.txt not found at ml-model/whisper/${NC}"
    exit 1
fi

echo -e "\n${YELLOW}Creating temporary packaging directory...${NC}"
TEMP_DIR=$(mktemp -d)
echo "Temp directory: $TEMP_DIR"

# Copy model files
echo -e "\n${YELLOW}Copying model files...${NC}"
mkdir -p "$TEMP_DIR/code"
cp -r ml-model/whisper/model/* "$TEMP_DIR/"
echo "✓ Model files copied"

# Copy inference code
echo -e "\n${YELLOW}Copying inference code...${NC}"
cp ml-model/whisper/inference.py "$TEMP_DIR/code/"
echo "✓ inference.py copied"

# Copy requirements
echo -e "\n${YELLOW}Copying requirements.txt...${NC}"
cp ml-model/whisper/requirements.txt "$TEMP_DIR/code/"
echo "✓ requirements.txt copied"

# Create tar.gz
echo -e "\n${YELLOW}Creating model.tar.gz...${NC}"
cd "$TEMP_DIR"
tar -czf model.tar.gz *
cd - > /dev/null

# Move to project root
mv "$TEMP_DIR/model.tar.gz" .
echo "✓ model.tar.gz created"

# Get file size
SIZE=$(ls -lh model.tar.gz | awk '{print $5}')
echo -e "\n${GREEN}✓ Model packaged successfully!${NC}"
echo -e "${YELLOW}File: model.tar.gz (Size: $SIZE)${NC}"

# Cleanup
rm -rf "$TEMP_DIR"
echo "✓ Cleanup complete"

# Show contents
echo -e "\n${YELLOW}Package contents:${NC}"
tar -tzf model.tar.gz | head -20
echo "..."
