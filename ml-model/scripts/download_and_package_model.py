#!/usr/bin/env python3
"""
Download Whisper Large V3 Turbo model from Hugging Face and package for SageMaker.

Usage:
    python scripts/download_and_package_model.py --s3-bucket YOUR_BUCKET_NAME
"""

import argparse
import json
import logging
import os
import shutil
import sys
import tarfile
import tempfile
from pathlib import Path

import boto3
from transformers import AutoModelForSpeechSeq2Seq, AutoProcessor

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


def download_model(model_name, output_dir):
    """Download Whisper model and processor from Hugging Face."""
    logger.info(f"Downloading model: {model_name}")

    model_dir = Path(output_dir) / "model"
    model_dir.mkdir(parents=True, exist_ok=True)

    logger.info("Downloading processor...")
    processor = AutoProcessor.from_pretrained(model_name)
    processor.save_pretrained(str(model_dir))
    logger.info(f"✓ Processor saved to {model_dir}")

    logger.info("Downloading model (this may take a few minutes)...")
    model = AutoModelForSpeechSeq2Seq.from_pretrained(model_name)
    model.save_pretrained(str(model_dir))
    logger.info(f"✓ Model saved to {model_dir}")

    # Verify model files
    model_files = list(model_dir.glob("*"))
    logger.info(f"✓ Model files: {len(model_files)} files")
    for f in sorted(model_files)[:5]:  # Show first 5 files
        logger.info(f"  - {f.name}")

    return model_dir


def create_sagemaker_package(model_dir, ml_model_dir, output_file):
    """Create SageMaker-compatible package structure."""
    logger.info("Creating SageMaker package structure...")

    with tempfile.TemporaryDirectory() as tmpdir:
        tmpdir = Path(tmpdir)

        # Create directory structure
        code_dir = tmpdir / "code"
        code_dir.mkdir(exist_ok=True)
        model_target = tmpdir / "model"

        # Copy model files
        logger.info(f"Copying model from {model_dir} to {model_target}")
        shutil.copytree(model_dir, model_target)

        # Copy inference code
        logger.info("Copying inference code...")
        ml_model_dir = Path(ml_model_dir)

        inference_py = ml_model_dir / "whisper" / "inference.py"
        if not inference_py.exists():
            raise FileNotFoundError(f"inference.py not found at {inference_py}")
        shutil.copy(inference_py, code_dir / "inference.py")
        logger.info(f"✓ Copied {inference_py.name}")

        serve_flask = ml_model_dir / "serve_flask.py"
        if not serve_flask.exists():
            raise FileNotFoundError(f"serve_flask.py not found at {serve_flask}")
        shutil.copy(serve_flask, code_dir / "serve_flask.py")
        logger.info(f"✓ Copied {serve_flask.name}")

        serve_script = ml_model_dir / "serve"
        if not serve_script.exists():
            raise FileNotFoundError(f"serve script not found at {serve_script}")
        shutil.copy(serve_script, code_dir / "serve")
        os.chmod(code_dir / "serve", 0o755)
        logger.info(f"✓ Copied serve script")

        # Create tar.gz package
        logger.info(f"Creating tar.gz package: {output_file}")
        with tarfile.open(output_file, "w:gz") as tar:
            # Add model files at root level (SageMaker expects config.json at root)
            for file in model_target.iterdir():
                tar.add(file, arcname=file.name)
            # Add code files at root level
            for file in code_dir.iterdir():
                tar.add(file, arcname=file.name)

        file_size_mb = os.path.getsize(output_file) / (1024 * 1024)
        logger.info(f"✓ Package created: {output_file}")
        logger.info(f"✓ Package size: {file_size_mb:.2f} MB")

    return output_file


def upload_to_s3(local_file, s3_bucket, s3_prefix="whisper-large-v3-turbo"):
    """Upload model package to S3."""
    logger.info(f"Uploading to S3: s3://{s3_bucket}/{s3_prefix}/")

    s3_client = boto3.client("s3")

    # Verify bucket exists
    try:
        s3_client.head_bucket(Bucket=s3_bucket)
        logger.info(f"✓ S3 bucket {s3_bucket} exists")
    except Exception as e:
        logger.error(f"✗ S3 bucket {s3_bucket} not accessible: {e}")
        raise

    # Upload file
    s3_key = f"{s3_prefix}/model.tar.gz"
    logger.info(f"Uploading {local_file} to s3://{s3_bucket}/{s3_key}")

    file_size_mb = os.path.getsize(local_file) / (1024 * 1024)
    logger.info(f"File size: {file_size_mb:.2f} MB")

    try:
        s3_client.upload_file(local_file, s3_bucket, s3_key)
        logger.info(f"✓ Upload complete!")
        logger.info(f"✓ S3 URI: s3://{s3_bucket}/{s3_key}")
        return f"s3://{s3_bucket}/{s3_key}"
    except Exception as e:
        logger.error(f"✗ Upload failed: {e}")
        raise


def main():
    parser = argparse.ArgumentParser(
        description="Download Whisper model and package for SageMaker"
    )
    parser.add_argument(
        "--s3-bucket",
        required=True,
        help="S3 bucket name for model artifacts (e.g., sagemaker-whisper-models-123456789-eu-west-1)"
    )
    parser.add_argument(
        "--model-name",
        default="openai/whisper-large-v3-turbo",
        help="Hugging Face model name"
    )
    parser.add_argument(
        "--output-dir",
        default="./whisper",
        help="Local directory to save model"
    )
    parser.add_argument(
        "--package-file",
        default="whisper-large-v3-turbo-model.tar.gz",
        help="Output tar.gz filename"
    )
    parser.add_argument(
        "--skip-upload",
        action="store_true",
        help="Skip S3 upload (for testing)"
    )

    args = parser.parse_args()

    try:
        # Step 1: Download model
        logger.info("=" * 70)
        logger.info("STEP 1: Downloading Whisper model")
        logger.info("=" * 70)
        model_dir = download_model(args.model_name, args.output_dir)

        # Step 2: Create SageMaker package
        logger.info("\n" + "=" * 70)
        logger.info("STEP 2: Creating SageMaker package")
        logger.info("=" * 70)
        ml_model_dir = Path(__file__).parent.parent
        package_file = create_sagemaker_package(
            model_dir,
            ml_model_dir,
            args.package_file
        )

        # Step 3: Upload to S3
        if not args.skip_upload:
            logger.info("\n" + "=" * 70)
            logger.info("STEP 3: Uploading to S3")
            logger.info("=" * 70)
            s3_uri = upload_to_s3(package_file, args.s3_bucket)

            logger.info("\n" + "=" * 70)
            logger.info("SUCCESS!")
            logger.info("=" * 70)
            logger.info(f"Model downloaded, packaged, and uploaded successfully!")
            logger.info(f"S3 URI: {s3_uri}")
            logger.info("\nUse this URI in your Terraform variables:")
            logger.info(f"  sagemaker_model_s3_uri = \"{s3_uri}\"")
        else:
            logger.info("\n" + "=" * 70)
            logger.info("SUCCESS (S3 upload skipped)")
            logger.info("=" * 70)
            logger.info(f"Model downloaded and packaged successfully!")
            logger.info(f"Package file: {package_file}")
            logger.info("\nTo upload manually:")
            logger.info(f"  aws s3 cp {package_file} s3://{args.s3_bucket}/whisper-large-v3-turbo/model.tar.gz")

        return 0

    except Exception as e:
        logger.error(f"\n✗ Error: {e}")
        logger.error("Script failed!")
        return 1


if __name__ == "__main__":
    sys.exit(main())
