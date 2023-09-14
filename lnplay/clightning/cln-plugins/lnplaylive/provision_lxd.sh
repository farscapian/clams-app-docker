#!/bin/bash

set -exu

if ! lxc remote list | grep -q lnplaylive; then
    lxc remote add lnplaylive -q "$LNPLAY_LXD_FQDN_PORT" --password "$LNPLAY_LXD_PASSWORD" --accept-certificate > /dev/null
fi

if ! lxc remote get-default | grep -q lnplaylive; then
    lxc remote switch lnplaylive  > /dev/null
else
    echo "WARNING: The lxc remote WAS NOT set to local. This could mean a prior deployment left the system in an odd state."
fi

PROJECT_NAME="project-name-unix-expiration-date"
if ! lxc project list | grep -q "$PROJECT_NAME"; then
    lxc project create "$PROJECT_NAME" > /dev/null
fi

if ! lxc project list | grep -q "$PROJECT_NAME (current)"; then
    lxc project switch "$PROJECT_NAME"  > /dev/null
fi

REMOTE_CONF_PATH="$HOME/ss/remotes/$(lxc remote get-default)"
mkdir -p "$REMOTE_CONF_PATH"  > /dev/null

REMOTE_CONF_FILE_PATH="$REMOTE_CONF_PATH/remote.conf"
# need to get the remote.conf in there
cat > "$REMOTE_CONF_FILE_PATH" <<EOF
LXD_REMOTE_PASSWORD=
DEPLOYMENT_STRING=
# REGISTRY_URL=http://registry.domain.tld:5000
EOF

# need to get the project.conf in there
PROJECT_CONF_PATH="$REMOTE_CONF_PATH/projects/$PROJECT_NAME"
mkdir -p "$PROJECT_CONF_PATH"  > /dev/null

PROJECT_CONF_FILE_PATH="$PROJECT_CONF_PATH/project.conf"

# todo, there needs to be some database/file of mac_addresses that can be used.
export VM_MAC_ADDRESS="MAC_ADDRESS"
cat > "$PROJECT_CONF_FILE_PATH" <<EOF
PRIMARY_DOMAIN="${DOMAIN_NAME}"
LNPLAY_SERVER_MAC_ADDRESS=${VM_MAC_ADDRESS}
# LNPLAY_SERVER_CPU_COUNT="4"
# LNPLAY_SERVER_MEMORY_MB="4096"
EOF

# need to get the site.conf in there
cd /sovereign-stack

sleep 60
#./deployment/up.sh

# set the project to default
lxc project switch default  > /dev/null

# set the remote to local.
lxc remote switch local  > /dev/null
