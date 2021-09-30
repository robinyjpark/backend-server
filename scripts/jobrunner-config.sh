#!/bin/bash
# Set up config files for the job-runner service
set -euo pipefail

BACKEND_DIR=$1

# set default file creation permission for this script be 640 for files and 750
# for directories
umask 027

# ensure shared user is set up properly
if id -u jobrunner 2>/dev/null; then
    # ensure jobrunner is in docker group
    usermod -a -G docker jobrunner
    # ensure jobrunner group ids
    usermod -u 10000 jobrunner
    groupmod -g 10000 jobrunner
else
    useradd jobrunner --create-home --shell /bin/bash --uid 10000 -G docker
fi


DIR=/srv/jobrunner
mkdir -p $DIR

# service configuration
mkdir -p $DIR/secret
mkdir -p $DIR/environ
defaults_env="$DIR/environ/01_defaults.env"
secrets_env="$DIR/environ/02_secrets.env"
backend_env="$DIR/environ/03_backend.env"
local_env="$DIR/environ/04_local.env"

copy_with_warning() {
    local src=$1
    local dst=$2

    test -f "$dst" && cp "$dst" "$dst.bak"

    cat > "$dst" << EOF
# DO NOT EDIT THIS FILE MANUALLY!
#
# It is automatically updated by the infrastructure code.
#
# Add any local overrides to into $local_env
#
EOF
    cat "$src" >> "$dst"
}

copy_with_warning jobrunner/defaults.env "$defaults_env"
copy_with_warning "$BACKEND_DIR/backend.env" "$backend_env"

# TODO: test for new secrets in template not in env?
test -f $secrets_env || cp jobrunner/secrets-template.env $secrets_env


# just make sure local env exists
test -f "$local_env" || echo "# add local overrides here" > "$local_env"

# utility for injecting test config
if test -f "${TEST_CONFIG:-}"; then
    cat "$TEST_CONFIG" >>"$local_env"
fi

# load config
set -a
# shellcheck disable=SC1090
for f in "$DIR"/environ/*.env; do
    # shellcheck disable=1090
    . "$f"
done
set +a;


# setup output directories
for output_dir in "$HIGH_PRIVACY_STORAGE_BASE" "$MEDIUM_PRIVACY_STORAGE_BASE"; do
    mkdir -p "$output_dir/workspaces"
    chown -R jobrunner:jobrunner "$output_dir"
    # only group read access, no world access
    find "$output_dir" -type f -exec chmod 640 {} +
done
