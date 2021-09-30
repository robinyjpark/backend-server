#!/bin/bash
set -euo pipefail

# start the docker container
DIR=~jobrunner/job-runner
echo "Pulling image"
# TODO: is this name job-runner or jobrunner?
docker-compose --no-ansi -f $DIR/docker-compose.yaml pull --quiet job-runner
docker-compose --no-ansi -f $DIR/docker-compose.yaml up --detach job-runner



