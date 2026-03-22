#!/usr/bin/env bash
# Git textconv driver for *.ipynb diffs.
# Git passes a temp file path as $1; we mount it read-only and stream stripped output to stdout.
set -euo pipefail

IMAGE_NAME="mlops-nbstripout"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DOCKERFILE="$REPO_ROOT/docker/nbstripout.Dockerfile"

if ! docker image inspect "$IMAGE_NAME" &>/dev/null; then
  echo "Image '$IMAGE_NAME' not found. Building..." >&2
  docker build -f "$DOCKERFILE" -t "$IMAGE_NAME" "$REPO_ROOT" >&2
fi

docker run --rm -i "$IMAGE_NAME" nbstripout < "$1"
