#!/bin/bash
# Run an ubuntu docker "VM", then run the passed command inside it.  The
# container is deleted when this script exits.
#
# Run with DEBUG=1 to run a shell inside the container after running your
# script
# 
# Note: you may need to first build the test image before you can manually run
# this script:
#     
#     make test-image
#
set -euo pipefail
TEST_IMAGE=backend-server-test
DEBUG=${DEBUG:-}

# Launch a container running systemd
CONTAINER="$(
    docker run -d --rm \
               --cap-add SYS_ADMIN --tmpfs /tmp --tmpfs /run --tmpfs /run/lock -v /sys/fs/cgroup:/sys/fs/cgroup:ro \
               -v "$PWD:/tests" "$TEST_IMAGE"
)"

trap 'docker rm -f $CONTAINER >/dev/null' EXIT

test -n "$DEBUG" && set +e  # DEBUG mode: do not exit if the test errors

# run test script
docker exec -i -e SHELLOPTS=xtrace -e TEST=true -w /tests "$CONTAINER" "$@"

if test -n "$DEBUG"; then
    echo "Running bash inside container (container will be deleted on exit)"
    docker exec -it -e TEST=true -w /tests "$CONTAINER" bash
fi
