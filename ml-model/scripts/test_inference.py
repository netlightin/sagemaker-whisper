#!/usr/bin/env python3
"""
Test the SageMaker inference script locally.

This script simulates SageMaker's inference flow by calling the functions
in inference.py with test data.
"""

import sys
import os
import json
import base64
import numpy as np
import wave
from io import BytesIO

# Add the ml-model/whisper directory to the path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'whisper'))

# Import the inference functions
from inference import model_fn, input_fn, predict_fn, output_fn

def generate_test_wav() -> bytes:
    """
    Generate a simple WAV file for testing.
    Returns the WAV file as bytes.
    """
    sample_rate = 16000
    duration = 3  # seconds
    frequency = 440  # Hz (A note)

    # Generate sine wave
    t = np.linspace(0, duration, int(sample_rate * duration))
    audio = np.sin(2 * np.pi * frequency * t)

    # Normalize to int16
    audio_int16 = (audio * 32767).astype(np.int16)

    # Create WAV file in memory
    wav_buffer = BytesIO()
    with wave.open(wav_buffer, 'wb') as wav_file:
        wav_file.setnchannels(1)  # Mono
        wav_file.setsampwidth(2)  # 2 bytes (16-bit)
        wav_file.setframerate(sample_rate)
        wav_file.writeframes(audio_int16.tobytes())

    wav_buffer.seek(0)
    return wav_buffer.read()

def test_inference_pipeline():
    """
    Test the complete inference pipeline.
    """
    print("="*70)
    print("TESTING SAGEMAKER INFERENCE PIPELINE")
    print("="*70)

    try:
        # Step 1: Load model
        print("\n" + "-"*70)
        print("Step 1: Testing model_fn()")
        print("-"*70)

        # Override MODEL_DIR for local testing
        model_dir = "./ml-model/whisper/model"

        if not os.path.exists(model_dir):
            print(f"✗ Model directory not found: {model_dir}")
            print("Please ensure the model has been downloaded first.")
            return False

        model_dict = model_fn(model_dir)
        print("✓ model_fn() succeeded")
        print(f"  - Device: {model_dict['device']}")
        print(f"  - Dtype: {model_dict['dtype']}")

        # Step 2: Test input_fn with different formats
        print("\n" + "-"*70)
        print("Step 2: Testing input_fn()")
        print("-"*70)

        # Generate test audio
        test_wav = generate_test_wav()
        print(f"Generated test WAV: {len(test_wav)} bytes")

        # Test 2a: JSON with base64 audio
        print("\nTest 2a: JSON with base64 encoded audio")
        audio_base64 = base64.b64encode(test_wav).decode('utf-8')
        json_request = {
            "audio": audio_base64,
            "language": "en",
            "task": "transcribe"
        }
        json_body = json.dumps(json_request).encode('utf-8')

        input_data = input_fn(json_body, content_type="application/json")
        print("✓ input_fn() with JSON succeeded")
        print(f"  - Audio shape: {input_data['audio'].shape}")
        print(f"  - Sample rate: {input_data['sample_rate']} Hz")
        print(f"  - Duration: {input_data['duration']:.2f} seconds")
        print(f"  - Language: {input_data['language']}")
        print(f"  - Task: {input_data['task']}")

        # Test 2b: Raw bytes
        print("\nTest 2b: Raw audio bytes")
        input_data_raw = input_fn(test_wav, content_type="application/octet-stream")
        print("✓ input_fn() with raw bytes succeeded")
        print(f"  - Audio shape: {input_data_raw['audio'].shape}")

        # Step 3: Test predict_fn
        print("\n" + "-"*70)
        print("Step 3: Testing predict_fn()")
        print("-"*70)

        prediction = predict_fn(input_data, model_dict)
        print("✓ predict_fn() succeeded")
        print(f"  - Transcription: \"{prediction['transcription']}\"")
        print(f"  - Language: {prediction['language']}")
        print(f"  - Task: {prediction['task']}")
        print(f"  - Inference time: {prediction['inference_time_seconds']:.3f}s")
        print(f"  - Audio duration: {prediction['audio_duration_seconds']:.2f}s")

        # Step 4: Test output_fn
        print("\n" + "-"*70)
        print("Step 4: Testing output_fn()")
        print("-"*70)

        # Test JSON output
        print("\nTest 4a: JSON output")
        json_output = output_fn(prediction, accept="application/json")
        output_dict = json.loads(json_output.decode('utf-8'))
        print("✓ output_fn() with JSON succeeded")
        print(f"  Output: {json.dumps(output_dict, indent=2)}")

        # Test text output
        print("\nTest 4b: Plain text output")
        text_output = output_fn(prediction, accept="text/plain")
        print("✓ output_fn() with text/plain succeeded")
        print(f"  Output: \"{text_output.decode('utf-8')}\"")

        # Summary
        print("\n" + "="*70)
        print("✓ ALL TESTS PASSED")
        print("="*70)
        print("\nThe SageMaker inference pipeline is working correctly!")
        print("The inference.py script is ready for deployment.")

        return True

    except Exception as e:
        print(f"\n✗ Test failed: {str(e)}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    success = test_inference_pipeline()
    sys.exit(0 if success else 1)
