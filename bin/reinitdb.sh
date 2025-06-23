#!/bin/bash
# Reinitialize the database by clearing the data directory (except for .gitkeep) and then bringing up docker-compose up 

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(realpath "$SCRIPT_DIR/..")"
DATA_DIR="$ROOT_DIR/data"
DOCKER_COMPOSE_FILE="$ROOT_DIR/docker-compose.yml"


has_running_containers() {
    
    # check if the root directory exists
    if [ ! -d "$ROOT_DIR" ]; then
        echo "Root directory does not exist: $ROOT_DIR" >&2
        return 1
    fi

    # check for docker-compose.yml file in root directory
    if [ ! -f "$DOCKER_COMPOSE_FILE" ]; then
        echo "No docker-compose.yml found in $ROOT_DIR" >&2
        return 1
    fi

    # check for running containers (docker compose only)
    CONTAINER_IDS="$(cd "$ROOT_DIR" && docker-compose ps --status running -q | wc -l | xargs)"
    if [ "$CONTAINER_IDS" -gt 0 ]; then
        return 0 # Yes, there are running containers
    fi
    return 1 # No running containers
}


# ==============================================
# Runtime
# ==============================================

# Check for and build the data directory if missing.
if [ ! -d "$DATA_DIR" ]; then
    echo "Data directory does not exist: $DATA_DIR"
    echo "Creating data directory..."
    mkdir -p "$DATA_DIR"
fi

# Normalize the data directory path
DATA_DIR="$(realpath "$DATA_DIR")"


# DOCKER CHECK
if has_running_containers; then
    echo "Attempting to stop running containers in $ROOT_DIR..."
    (cd "$ROOT_DIR" && docker-compose down)
    if [ $? -ne 0 ]; then
        echo "Failed to stop running containers. Please check your Docker setup." >&2
        exit 1
    fi
    # re-confirm
    if has_running_containers; then
        echo "There are still running containers after attempting to stop them. Aborting reinitialization." >&2
        exit 1
    else
        echo "Successfully stopped all running containers."
    fi
fi


# DATA DIRECTORY CHECK
if [ ! -d "$DATA_DIR" ]; then
    echo "Data directory does not exist: $DATA_DIR" >&2
    echo "Aborting reinitialization to prevent accidental deletion behavior." >&2
    exit 1
fi

# REMOVE ALL CONTENTS, EXCEPT .gitkeep
find "$DATA_DIR" -mindepth 1 ! -name '.gitkeep' -exec rm -rf {} +

# REINITIALIZE DOCKER
echo "Running `docker-compose up` to reinitialize the database and display the logs..."
exec docker-compose -f "$DOCKER_COMPOSE_FILE" up


