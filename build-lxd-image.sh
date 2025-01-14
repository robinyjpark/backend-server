#!/bin/bash
set -euo pipefail
name=${1-backend-server-test}

lxc image delete "$name" || true
lxc delete -f "$name" || true
lxc launch ubuntu:20.04 "$name" --quiet -c security.nesting=true
lxc exec "$name" -- cloud-init status --wait

# install stuff
sed 's/^#.*//' purge-packages.txt | lxc exec "$name" -- xargs apt-get purge -y
lxc exec "$name" -- apt-get autoremove --yes
lxc exec "$name" -- apt-get update
lxc exec "$name" -- apt-get upgrade --yes
sed 's/^#.*//' core-packages.txt | lxc exec "$name" -- xargs apt-get install -y
sed 's/^#.*//' packages.txt | lxc exec "$name" -- xargs apt-get install -y

lxc stop "$name"
time lxc publish --quiet "$name" --alias "$name"
# GHA version of lxd doesn't have this, so don't error
lxc image set-property "$name" description "Test image for backend-server project" || true
lxc delete "$name"
