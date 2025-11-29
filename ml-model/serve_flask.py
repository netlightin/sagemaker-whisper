#!/usr/bin/env python3
"""
Flask-based SageMaker inference server for Whisper.
No Java required - lightweight and fast.
"""

import os
import sys
import json
import base64
import io
import logging
from flask import Flask, request, jsonify

# Add code directory to path
sys.path.insert(0, '/opt/ml/code')

# Import inference functions
from inference import model_fn, input_fn, predict_fn, output_fn

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Create Flask app
app = Flask(__name__)

# Load model at startup
logger.info("Loading Whisper model...")
model = model_fn('/opt/ml/model')
logger.info("Model loaded successfully!")


@app.route('/ping', methods=['GET'])
def ping():
    """Health check endpoint."""
    return jsonify({'status': 'healthy'}), 200


@app.route('/invocations', methods=['POST'])
def invocations():
    """Inference endpoint."""
    try:
        # Get request data
        if request.content_type == 'application/json':
            data = request.get_json()
        else:
            data = request.data

        # Process input
        logger.info("Processing input...")
        processed_input = input_fn(data, request.content_type)

        # Make prediction
        logger.info("Running inference...")
        prediction = predict_fn(processed_input, model)

        # Format output
        logger.info("Formatting output...")
        output = output_fn(prediction, 'application/json')

        return output, 200, {'Content-Type': 'application/json'}

    except Exception as e:
        logger.error(f"Inference error: {str(e)}", exc_info=True)
        return jsonify({'error': str(e)}), 500


if __name__ == '__main__':
    # Start server on port 8080
    port = int(os.environ.get('SAGEMAKER_BIND_TO_PORT', 8080))
    logger.info(f"Starting Flask server on port {port}")
    app.run(host='0.0.0.0', port=port, threaded=True)
