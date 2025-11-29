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

# Download model inside container to /tmp, then copy to mounted host volume
docker-compose run --rm \
    -v "$(pwd)/ml-model/whisper/model:/host-model:rw" \
    ml-dev \
    bash -c '
python -c "
import os
from transformers import AutoModelForSpeechSeq2Seq, AutoProcessor
import torch

model_name = \"openai/whisper-large-v3-turbo\"
save_dir = \"/tmp/whisper-model\"

print(f\"Downloading {model_name}...\")
print(f\"Save directory: {save_dir}\")

os.makedirs(save_dir, exist_ok=True)

device = \"cuda\" if torch.cuda.is_available() else \"cpu\"
torch_dtype = torch.float16 if torch.cuda.is_available() else torch.float32

print(f\"Device: {device}\")

processor = AutoProcessor.from_pretrained(model_name)
processor.save_pretrained(save_dir)
print(\"✓ Processor downloaded\")

model = AutoModelForSpeechSeq2Seq.from_pretrained(
    model_name,
    torch_dtype=torch_dtype,
    low_cpu_mem_usage=True,
)
model.save_pretrained(save_dir)
print(\"✓ Model downloaded\")
print(f\"✓ Model saved to {save_dir}\")
" && \
echo "Copying model files to host..." && \
cp -r /tmp/whisper-model/* /host-model/ && \
echo "✓ Model copied to host"
'

echo -e "\n${GREEN}✓ Model downloaded successfully!${NC}"
echo -e "${YELLOW}Model location: ml-model/whisper/model/${NC}"
