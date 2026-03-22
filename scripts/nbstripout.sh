#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="mlops-nbstripout"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DOCKERFILE="$REPO_ROOT/docker/nbstripout.Dockerfile"

if ! docker image inspect "$IMAGE_NAME" &>/dev/null; then
  echo "Image '$IMAGE_NAME' not found. Building..."
  docker build -f "$DOCKERFILE" -t "$IMAGE_NAME" "$REPO_ROOT"
fi

if [ "$#" -gt 0 ]; then
  notebooks=("$@")
else
  notebooks=()
  while IFS= read -r nb; do
    [[ -n "$nb" ]] && notebooks+=("$nb")
  done < <(git -C "$REPO_ROOT" ls-files '*.ipynb')
fi

if [ "${#notebooks[@]}" -eq 0 ]; then
  echo "No notebooks found."
  exit 0
fi

echo "Stripping outputs from ${#notebooks[@]} notebook(s)..."
docker run --rm \
  -v "$REPO_ROOT:/work" \
  -w /work \
  "$IMAGE_NAME" \
  nbstripout "${notebooks[@]}"
echo "Done."
