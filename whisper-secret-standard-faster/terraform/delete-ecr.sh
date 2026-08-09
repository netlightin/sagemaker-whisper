#!/bin/bash

# List of repositories to force delete
REPOS=(
  "steep-hill-api"
  "steep-hill-inference"
)

REGION="eu-west-1"

for repo in "${REPOS[@]}"; do
  echo "Deleting repository $repo in region $REGION..."
  aws ecr delete-repository --repository-name "$repo" --region "$REGION" --force
  if [ $? -eq 0 ]; then
    echo "Deleted $repo successfully."
  else
    echo "Failed to delete $repo."
  fi
done