#!/bin/bash
set -euo pipefail

# start the docker container
DIR=~jobrunner/hatch
echo "Pulling image"
docker-compose --no-ansi -f $DIR/docker-compose.yaml pull --quiet release-hatch
docker-compose --no-ansi -f $DIR/docker-compose.yaml up --detach release-hatch



