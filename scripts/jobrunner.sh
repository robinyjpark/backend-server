#!/bin/bash
# Set up the job-runner service
set -euo pipefail
BACKEND=$1

# set default file creation permission for this script be 640 for files and 750
# for directories
umask 027

# ensure shared user is set up properly
id -u jobrunner >/dev/null 2>&1 || useradd jobrunner --create-home --shell /bin/bash -G docker

DIR=/srv/jobrunner
mkdir -p $DIR
# ensure we have a checkout of job-runner and dependencies
test -d $DIR/code || git clone https://github-proxy.opensafely.org/opensafely-core/job-runner $DIR/code
test -d $DIR/lib || git clone https://github-proxy.opensafely.org/opensafely-core/job-runner-dependencies $DIR/lib

# service configuration
mkdir -p $DIR/secret
mkdir -p $DIR/environ
mkdir -p $DIR/bin
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

cp jobrunner/bin/* /srv/jobrunner/bin/

copy_with_warning jobrunner/defaults.env "$defaults_env"
copy_with_warning "$BACKEND/backend.env" "$backend_env"

# TODO: test for new secrets in template not in env?
test -f $secrets_env || cp jobrunner/secrets-template.env $secrets_env


# just make sure local env exists
test -f "$local_env" || echo "# add local overrides here" > "$local_env"

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
    mkdir -p "$output_dir"
    # only group read access, no world access
    find "$output_dir" -type f -exec chmod 640 {} +
done
chown -R jobrunner:jobrunner "$HIGH_PRIVACY_STORAGE_BASE"
chown -R jobrunner:jobrunner "$MEDIUM_PRIVACY_STORAGE_BASE"

# ensure docker images present
# Note: does not update, as that is currently done manually

for image in cohortextractor python jupyter r base-docker busybox; do
    docker inspect "ghcr.io/opensafely-core/$image" > /dev/null 2>&1 || /srv/jobrunner/code/scripts/update-docker-image.sh "$image"
done
    

# set up some nice helpers for when we su into the shared jobrunner user
cp jobrunner/bashrc $DIR/bashrc
chmod 644 $DIR/bashrc
test -f ~jobrunner/.bashrc || touch ~jobrunner/.bashrc
grep -q "jobrunner/bashrc" ~jobrunner/.bashrc || echo 'test -f /srv/jobrunner/bashrc && . /srv/jobrunner/bashrc' >> ~jobrunner/.bashrc

# update playbook
cp jobrunner/playbook.md /srv/jobrunner/playbook.md
ln -sf "/srv/jobrunner/playbook.md" ~jobrunner/playbook.md

# clean up old playbook if present
rm -rf /srv/playbook.md

# ensure file ownership and permissions
chown -R jobrunner:jobrunner /srv/jobrunner
chmod 0600 $secrets_env
chmod 0700 $DIR/secret
find $DIR/secret -type f -exec chmod 0600 {} \;

# set up systemd service
# Note: do this *after* permissions have been set on the /srv/jobrunner properly
cp jobrunner/jobrunner.service /etc/systemd/system/
cp jobrunner/jobrunner.sudo /etc/sudoers.d/jobrunner
systemctl enable --now jobrunner

