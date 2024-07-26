#!/bin/bash

# List of image URLs to pull
source_images=(
  "docker://docker.io/library/ubuntu:latest"
  "docker://docker.io/library/nginx:latest"
  "docker://docker.io/library/node:latest"
)

# Target registry
target_registry="myregistry.example.com"

# Timeout in seconds for each operation
timeout=60

# Function to pull and push an image with infinite retry mechanism
pull_and_push_image() {
  local source_image=$1
  local target_image=$2
  local attempt=1

  while true; do
    echo "Pulling $source_image (Attempt $attempt)..."
    timeout $timeout skopeo copy "$source_image" "dir:/tmp/$(basename "$source_image")"
    if [ $? -eq 0 ]; then
      break
    else
      echo "Pull failed or timed out, retrying in 5 seconds..."
      attempt=$((attempt + 1))
      sleep 5
    fi
  done

  attempt=1
  while true; do
    echo "Pushing $target_image (Attempt $attempt)..."
    timeout $timeout skopeo copy "dir:/tmp/$(basename "$source_image")" "$target_image"
    if [ $? -eq 0 ]; then
      break
    else
      echo "Push failed or timed out, retrying in 5 seconds..."
      attempt=$((attempt + 1))
      sleep 5
    fi
  done

  echo "Successfully pulled $source_image and pushed to $target_image."
  return 0
}

# Iterate over the list of images and pull/push each one
for source_image in "${source_images[@]}"; do
  # Construct the target image URL
  image_name=$(basename "$source_image")
  target_image="docker://$target_registry/$image_name"
  pull_and_push_image "$source_image" "$target_image"
done
