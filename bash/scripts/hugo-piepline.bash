#!/bin/bash

# Fail immediately, this script must be successful at every point
# to prevent needless cleanup and operations
set -e

API_TOKEN=$(cat secrets.token) # Not exactly super secure :]
ZONE_ID=$(cat secrets.zone)
WEB_USER=www-data/apache
WEB_TOOL=nginx/apache2
REMOTE_USER=username
REMOTE_HOST=ip address

NEW_RELEASE="/var/www/releases/release_$(date +"%s_%Y-%m-%d")/"
WEB_DIR="/var/www/public"

# Needed for passphrased ssh key #
trap 'ssh-agent -k' EXIT

if [[ -z "$SSH_AUTH_SOCK" ]]; then
    eval "$(ssh-agent)"
fi
ssh-add ~/.ssh/{key_dir}/{private_key}
##################################

hugo --logLevel error && rsync -avzh --delete public "${REMOTE_USER}"@"${REMOTE_HOST}":/tmp/

ssh -t "${REMOTE_USER}"@"${REMOTE_HOST}" "sudo bash -e -c '
    mkdir -p ${NEW_RELEASE}
    cp -r /tmp/public/* ${NEW_RELEASE}/
    chown -R ${WEB_USER}:${WEB_USER} ${NEW_RELEASE}
    find ${NEW_RELEASE} -type d -exec chmod 755 {} +
    find ${NEW_RELEASE} -type f -exec chmod 644 {} +
    # Link /var/www/public (web root) to /var/www/releases/{current_release}
    ln -snf ${NEW_RELEASE} ${WEB_DIR}
    systemctl restart ${WEB_TOOL}
    # Keep 5 releases/versions of pushes
    ls -1dt /var/www/releases/* | tail -n +6 | xargs rm -rf
'"

curl -X POST "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/purge_cache" \
    -H "Authorization: Bearer ${API_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{"purge_everything": true}'
