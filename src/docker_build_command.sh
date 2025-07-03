# Actual logic from bin/build.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(realpath "$SCRIPT_DIR/..")"
DOCKERFILE="${get_setting dockerfile:-"$ROOT_DIR/Dockerfile"}"
TAG="${get_setting tag:-"veloper/pgkeen:latest"}"
PUSH="${get_setting push:-1}"




cmd="docker build --tag "$TAG" --file "$DOCKERFILE" "$ROOT_DIR""
if [[ $PUSH -eq 1 ]]; then
    cmd+=" --push"
fi

info "Building Docker image: $TAG"
exec $cmd
