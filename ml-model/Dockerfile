# Multi-stage Dockerfile for Whisper model development and testing
# This can be used for both local development and SageMaker deployment

FROM python:3.11-slim as base

# Set working directory
WORKDIR /opt/ml

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libsndfile1 \
    ffmpeg \
    git \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better caching
COPY whisper/requirements.txt /opt/ml/code/requirements.txt

# Install Python dependencies
RUN pip install --no-cache-dir -r /opt/ml/code/requirements.txt

# Development stage - includes additional dev tools
FROM base as development

# Install development dependencies
RUN pip install --no-cache-dir \
    ipython \
    jupyter \
    pytest \
    black \
    flake8

# Copy all source code
COPY . /opt/ml/code/

# Set Python path
ENV PYTHONPATH=/opt/ml/code

# Default command for development
CMD ["/bin/bash"]

# SageMaker inference stage
FROM base as sagemaker

# Copy only necessary files for inference
COPY whisper/inference.py /opt/ml/code/inference.py
COPY whisper/model/ /opt/ml/model/

# Set environment variables for SageMaker
ENV PYTHONUNBUFFERED=TRUE
ENV PYTHONDONTWRITEBYTECODE=TRUE
ENV PATH="/opt/ml/code:${PATH}"
ENV PYTHONPATH=/opt/ml/code

# SageMaker uses this working directory
WORKDIR /opt/ml/code

# Expose port for SageMaker serving
EXPOSE 8080

# Entry point for SageMaker
ENTRYPOINT ["python"]
