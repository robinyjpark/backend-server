#!/bin/bash
set -euo pipefail
user=$1
TEST=${TEST:-}

# generate clean authorized_keys file from current sources list. This
# will drop keys that have been removed from this repo or from github
tmp=$(mktemp)

# start with explicit keys from this repo
if test -f "keys/$user"; then
    cat "keys/$user" > "$tmp"
fi

# workaround for gh ratelimits when runing tests locally
cache=.ssh-key-cache/$user
# if we have a cached file, and TEST is set, then use cache
if test -f "$cache" -a -n "${TEST}"; then
    cat "$cache" >> "$tmp"
else
    # add current gh keys into $tmp
    curl -s "https://github.com/$user.keys" -o "$tmp"
fi

# replace current authorized_keys
mkdir -p "/home/$user/.ssh"
mv "$tmp" "/home/$user/.ssh/authorized_keys"
chown -R "$user:$user" "/home/$user/.ssh/"
