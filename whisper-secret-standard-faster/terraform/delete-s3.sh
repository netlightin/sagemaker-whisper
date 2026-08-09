#!/bin/bash

BUCKET="sagemaker-steep-hill-models-654654436000-eu-west-1"

echo "Deleting all objects from bucket: $BUCKET"
aws s3 rm "s3://$BUCKET" --recursive

echo "Deleting bucket: $BUCKET"
aws s3api delete-bucket --bucket "$BUCKET" --region eu-west-1

echo "Done."