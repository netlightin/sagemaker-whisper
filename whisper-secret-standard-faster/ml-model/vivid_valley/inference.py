"""
SageMaker inference script for KB-Whisper using faster-whisper.

This script implements the required functions for SageMaker inference:
- model_fn: Load the model using faster-whisper (ctranslate2 backend)
- input_fn: Parse and preprocess input data
- predict_fn: Run inference with optimized faster-whisper
- output_fn: Format the output

Supports multiple input formats:
- Base64 encoded audio
- Raw bytes
- S3 URLs
- JSON with audio data and parameters

faster-whisper provides optimized inference via ctranslate2 and is significantly
faster than the original Whisper implementation.
"""

import os
import json
import logging
import base64
import time
from io import BytesIO
from typing import Dict, Any, Optional, Tuple
import traceback

import torch
import numpy as np
from faster_whisper import WhisperModel
import soundfile as sf

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="[%(asctime)s] %(levelname)s - %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger(__name__)

# Constants
MODEL_DIR = "/opt/ml/model"
DEFAULT_SAMPLE_RATE = 16000
MAX_AUDIO_LENGTH_SECONDS = None  # No hard limit - hardware resources are the constraint


def model_fn(model_dir: str = MODEL_DIR) -> Dict[str, Any]:
    """
    Load the Whisper model using faster-whisper (ctranslate2 backend).

    This function is called once when the endpoint is created.
    faster-whisper provides optimized inference via ctranslate2.

    Args:
        model_dir: Directory containing the model files (or model ID for HuggingFace)

    Returns:
        Dictionary containing the model and device info

    Raises:
        Exception: If model loading fails
    """
    logger.info("=" * 60)
    logger.info("Loading Whisper model with faster-whisper...")
    logger.info("=" * 60)

    try:
        start_time = time.time()

        # GPU-only mode: fail immediately if CUDA is not available
        if not torch.cuda.is_available():
            raise RuntimeError(
                "CUDA is not available. This model requires GPU acceleration. "
                "Ensure the SageMaker instance type has GPU support (e.g., ml.g5.xlarge, ml.p3.2xlarge)."
            )

        device = "cuda"
        compute_type = "float16"

        logger.info(f"Model directory: {model_dir}")
        logger.info(f"Device: {device}")
        logger.info(f"Compute type: {compute_type}")

        # Load model using faster-whisper
        # faster-whisper will download and cache the model automatically
        # You can use built-in models: "tiny", "base", "small", "medium", "large"
        # Or specify a custom model ID from HuggingFace
        model_id = os.environ.get("MODEL_ID", "base")
        logger.info(f"Loading model: {model_id}")

        # Use a writable cache directory (/opt/ml/model is read-only on SageMaker)
        # Prefer /tmp if available, otherwise fall back to /opt/ml/code
        if os.path.exists("/tmp"):
            cache_dir = "/tmp/whisper_cache"
        else:
            cache_dir = "/opt/ml/code/cache"

        os.makedirs(cache_dir, exist_ok=True)
        logger.info(f"Model cache directory: {cache_dir}")

        # Load model with GPU (required)
        model = WhisperModel(
            model_id,
            device=device,
            compute_type=compute_type,
            download_root=cache_dir,
        )
        logger.info("✓ Model loaded on GPU")

        load_time = time.time() - start_time
        logger.info(f"✓ Model loaded successfully in {load_time:.2f} seconds")
        logger.info(f"Final device: {device}, compute type: {compute_type}")
        logger.info("=" * 60)

        return {
            "model": model,
            "device": device,
            "compute_type": compute_type,
        }

    except Exception as e:
        logger.error(f"Failed to load model: {str(e)}")
        logger.error(traceback.format_exc())
        raise


def input_fn(
    request_body: bytes, content_type: str = "application/json"
) -> Dict[str, Any]:
    """
    Parse and preprocess the input data.

    Supported input formats:
    1. JSON with base64 encoded audio:
       {
         "audio": "<base64-string>",
         "language": "en",  // optional
         "task": "transcribe"  // optional: "transcribe" or "translate"
       }

    2. JSON with audio URL:
       {
         "audio_url": "s3://bucket/key",
         "language": "en"
       }

    3. Raw audio bytes (application/octet-stream)

    Args:
        request_body: Raw request body bytes
        content_type: Content type of the request

    Returns:
        Dictionary containing audio tensor and parameters

    Raises:
        ValueError: If input format is invalid
    """
    logger.info(f"Processing input with content_type: {content_type}")

    try:
        audio_data = None
        language = None
        task = "transcribe"
        sample_rate = DEFAULT_SAMPLE_RATE

        if content_type == "application/json":
            # Parse JSON input
            try:
                data = json.loads(request_body.decode("utf-8"))
            except json.JSONDecodeError as e:
                raise ValueError(f"Invalid JSON: {str(e)}")

            # Extract parameters
            language = data.get("language")
            task = data.get("task", "transcribe")

            # Get audio data
            if "audio" in data:
                # Base64 encoded audio
                try:
                    audio_base64 = data["audio"]
                    audio_bytes = base64.b64decode(audio_base64)
                    audio_data = audio_bytes
                    logger.info(f"Decoded base64 audio: {len(audio_bytes)} bytes")
                except Exception as e:
                    raise ValueError(f"Failed to decode base64 audio: {str(e)}")

            elif "audio_url" in data:
                # S3 URL or local path
                audio_url = data["audio_url"]
                logger.info(f"Loading audio from URL: {audio_url}")

                if audio_url.startswith("s3://"):
                    # Load from S3
                    import boto3

                    s3 = boto3.client("s3")
                    bucket, key = audio_url.replace("s3://", "").split("/", 1)

                    response = s3.get_object(Bucket=bucket, Key=key)
                    audio_data = response["Body"].read()
                    logger.info(f"Loaded audio from S3: {len(audio_data)} bytes")
                else:
                    # Load from local file (for testing)
                    with open(audio_url, "rb") as f:
                        audio_data = f.read()
                    logger.info(f"Loaded audio from file: {len(audio_data)} bytes")
            else:
                raise ValueError("Input must contain 'audio' (base64) or 'audio_url'")

        elif content_type == "application/octet-stream":
            # Raw audio bytes
            audio_data = request_body
            logger.info(f"Received raw audio: {len(audio_data)} bytes")

        else:
            raise ValueError(f"Unsupported content_type: {content_type}")

        # Load and process audio
        audio_tensor, sample_rate = load_audio(audio_data)
        logger.info(
            f"Audio loaded: {audio_tensor.shape[0]} samples at {sample_rate} Hz"
        )

        # Log audio duration
        duration = audio_tensor.shape[0] / sample_rate

        logger.info(f"Audio duration: {duration:.2f} seconds")

        return {
            "audio": audio_tensor,
            "sample_rate": sample_rate,
            "language": language,
            "task": task,
            "duration": duration,
        }

    except Exception as e:
        logger.error(f"Error processing input: {str(e)}")
        logger.error(traceback.format_exc())
        raise


def load_audio(audio_data: bytes) -> Tuple[np.ndarray, int]:
    """
    Load audio from bytes and convert to the required format.

    Args:
        audio_data: Raw audio bytes

    Returns:
        Tuple of (audio_array, sample_rate)

    Raises:
        ValueError: If audio format is not supported
    """
    try:
        # Load audio using soundfile
        audio_io = BytesIO(audio_data)
        audio_array, sample_rate = sf.read(audio_io, dtype="float32")

        # Convert to mono if stereo
        if len(audio_array.shape) > 1 and audio_array.shape[1] > 1:
            audio_array = np.mean(audio_array, axis=1)
            logger.info("Converted stereo to mono")

        # Resample to 16kHz if needed
        if sample_rate != DEFAULT_SAMPLE_RATE:
            logger.info(f"Resampling from {sample_rate} Hz to {DEFAULT_SAMPLE_RATE} Hz")
            # Use scipy or librosa for resampling
            import librosa

            audio_array = librosa.resample(
                audio_array, orig_sr=sample_rate, target_sr=DEFAULT_SAMPLE_RATE
            )
            sample_rate = DEFAULT_SAMPLE_RATE

        return audio_array, sample_rate

    except Exception as e:
        logger.error(f"Failed to load audio: {str(e)}")
        raise ValueError(f"Unsupported audio format: {str(e)}")


def predict_fn(
    input_data: Dict[str, Any], model_dict: Dict[str, Any]
) -> Dict[str, Any]:
    """
    Run inference on the input data using faster-whisper.

    faster-whisper handles audio chunking and streaming automatically,
    providing optimized inference via ctranslate2.

    Args:
        input_data: Preprocessed input from input_fn
        model_dict: Model from model_fn

    Returns:
        Dictionary containing transcription and metadata

    Raises:
        Exception: If inference fails
    """
    logger.info("Running inference with faster-whisper...")
    start_time = time.time()

    try:
        # Extract components
        model = model_dict["model"]

        audio = input_data["audio"]
        sample_rate = input_data["sample_rate"]
        language = input_data.get("language")
        task = input_data.get("task", "transcribe")
        duration = input_data.get("duration", 0)

        logger.info(f"Processing audio: {duration:.2f} seconds at {sample_rate} Hz")
        logger.info(f"Audio array shape: {audio.shape}, dtype: {audio.dtype}")

        # Prepare transcription kwargs
        transcribe_kwargs = {
            "condition_on_previous_text": False,  # Reduces hallucinations
            "language": language if language else None,
            "task": task,
        }

        logger.info(f"Transcription params: {transcribe_kwargs}")

        # Run inference using faster-whisper
        # transcribe() returns generator of segments with automatic chunking
        segments, info = model.transcribe(audio, **transcribe_kwargs)

        # Extract text from segments
        transcriptions = []
        for segment in segments:
            transcriptions.append(segment.text)
            logger.info(
                f"  Segment [{segment.start:.2f}s -> {segment.end:.2f}s]: {len(segment.text)} chars"
            )

        # Concatenate all segments
        transcription = " ".join(transcriptions).strip()

        inference_time = time.time() - start_time

        logger.info(f"✓ Inference completed in {inference_time:.3f} seconds")
        logger.info(f"Total transcription length: {len(transcription)} characters")
        if duration > 0:
            logger.info(f"Processing rate: {duration / inference_time:.2f}x realtime")

        # Get detected language from info
        detected_language = (
            info.language
            if hasattr(info, "language")
            else (language if language else "auto-detected")
        )
        language_probability = (
            info.language_probability if hasattr(info, "language_probability") else None
        )

        result = {
            "transcription": transcription,
            "language": detected_language,
            "task": task,
            "inference_time_seconds": inference_time,
            "audio_duration_seconds": duration,
            "model": "kb-whisper",
        }

        if language_probability:
            result["language_probability"] = language_probability

        return result

    except Exception as e:
        logger.error(f"Inference failed: {str(e)}")
        logger.error(traceback.format_exc())
        raise


def output_fn(prediction: Dict[str, Any], accept: str = "application/json") -> bytes:
    """
    Format the prediction output.

    Args:
        prediction: Prediction results from predict_fn
        accept: Desired output format

    Returns:
        Formatted output as bytes

    Raises:
        ValueError: If output format is not supported
    """
    logger.info(f"Formatting output with accept type: {accept}")

    try:
        if accept == "application/json" or accept == "*/*":
            # Return JSON
            metadata = {
                "language": prediction["language"],
                "task": prediction["task"],
                "model": prediction["model"],
                "inference_time_seconds": round(
                    prediction["inference_time_seconds"], 3
                ),
                "audio_duration_seconds": round(
                    prediction["audio_duration_seconds"], 2
                ),
            }

            # Include language probability if available (from faster-whisper)
            if "language_probability" in prediction:
                metadata["language_probability"] = round(
                    prediction["language_probability"], 4
                )

            output = {
                "success": True,
                "transcription": prediction["transcription"],
                "metadata": metadata,
            }
            return json.dumps(output, ensure_ascii=False).encode("utf-8")

        elif accept == "text/plain":
            # Return just the transcription text
            return prediction["transcription"].encode("utf-8")

        else:
            raise ValueError(f"Unsupported accept type: {accept}")

    except Exception as e:
        logger.error(f"Failed to format output: {str(e)}")
        logger.error(traceback.format_exc())

        # Return error response
        error_output = {"success": False, "error": str(e)}
        return json.dumps(error_output).encode("utf-8")


# Error handling wrapper (optional, for better error responses)
def handle_error(error: Exception) -> bytes:
    """
    Format error responses.

    Args:
        error: Exception that occurred

    Returns:
        JSON formatted error response
    """
    logger.error(f"Error occurred: {str(error)}")

    error_response = {
        "success": False,
        "error": str(error),
        "error_type": type(error).__name__,
    }

    return json.dumps(error_response).encode("utf-8")
