#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(realpath "$SCRIPT_DIR/..")"
DOCKERFILE="$ROOT_DIR/Dockerfile"

docker build \
    --tag "veloper/pgkeen:latest" \
    --file "$DOCKERFILE" "$ROOT_DIR" \
    --push # Push the image to the Docker registry

