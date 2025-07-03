SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(realpath "$SCRIPT_DIR")"

# Change working directory to the root directory
# or exit with an error if it fails
cd "$ROOT_DIR" || exit 1 


DATA_DIR="${ROOT_DIR}/${SETTINGS[data_dir]}"
DOCKER_COMPOSE_FILE="${ROOT_DIR}/${SETTINGS[docker_compose_file]}"

info "Checking data directory..."
if [ ! -d "$DATA_DIR" ]; then
    yellow "Postgres data directory does not exist: $DATA_DIR"
    info "Auto creating data directory..."
    mkdir -p "$DATA_DIR"
fi
DATA_DIR="$(realpath "$DATA_DIR")" # real pathing it here


info "Checking for docker-compose.yml file..."
if [ ! -f "$DOCKER_COMPOSE_FILE" ]; then
    error "Docker Compose file does not exist: $DOCKER_COMPOSE_FILE" >&2
    error "Please ensure you have a valid docker-compose.yml file in the root directory and try again." >&2
    exit 1
fi
DOCKER_COMPOSE_FILE="$(realpath "$DOCKER_COMPOSE_FILE")" # real pathing it here

info "Checking for running containers..."
if has_running_containers; then
    yellow "Attempting to stop running containers in $ROOT_DIR..."
    docker-compose down
    if [ $? -ne 0 ]; then
        error "Failed to stop running containers." >&2
        error "Please check your Docker setup and try again." >&2
        exit 1
    fi
fi



info "Reinitializing database..."
debug "This will clear the data directory, which allows the docker image to reinitialize the database."

# Remove all files in the data directory except .gitkeep
find "$DATA_DIR" -mindepth 1 ! -name '.gitkeep' -exec rm -rf {} +
if [ $? -ne 0 ]; then
    error "Failed to clear the data directory: $DATA_DIR" >&2
    error "Please check your permissions or the directory structure and try again." >&2
    exit 1
fi

info "Running `docker-compose up` in the background..."
docker-compose -f "$DOCKER_COMPOSE_FILE" up --detached
if [ $? -ne 0 ]; then
    error "Failed to start the Docker containers." >&2
    error "Please check your Docker Compose file and try again." >&2
    exit 1
fi

info "Tailing container logs in the foreground..."
info "You may exit with Ctrl+C at any time without stopping the container."
exec docker-compose -f "$DOCKER_COMPOSE_FILE" logs -f
