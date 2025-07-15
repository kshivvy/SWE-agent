#!/bin/bash

# Exit on error,
set -e

IMAGE_URI="us-central1-docker.pkg.dev/docker-rlef-exploration/sweagent-repo/sweagent-image:latest"

# Build the Docker image, tagging it for GCP Artifact Registry.
docker build -t "${IMAGE_URI}" .

# Authenticate Docker with GCP Artifact Registry.
gcloud auth configure-docker us-central1-docker.pkg.dev

# Push the image to GCP Artifact Registry.
docker push "${IMAGE_URI}"