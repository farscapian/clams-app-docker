#!/bin/bash

set -exu

if ! lxc remote list | grep -q lnplaylive; then
    lxc remote add lnplaylive "$LNPLAY_LXD_FQDN_PORT" --password "$LNPLAY_LXD_PASSWORD" --accept-certificate
fi

if ! lxc remote get-default | grep -q lnplaylive; then
    lxc remote switch lnplaylive
fi

if ! lxc project list | grep -q lnplaylive; then
    lxc project create lnplaylive
fi

if ! lxc project list | grep -q "default (current)"; then
    lxc project switch lnplaylive
fi

cd /sovereign-stack

REMOTE_CONF_PATH="$HOME/ss/remotes/$(lxc remote get-default)"
mkdir -p "$REMOTE_CONF_PATH"

REMOTE_CONF_FILE_PATH="$REMOTE_CONF_PATH/remote.conf"
# need to get the remote.conf in there
cat > "$REMOTE_CONF_FILE_PATH" <<EOF
LXD_REMOTE_PASSWORD=
DEPLOYMENT_STRING=
# REGISTRY_URL=http://registry.domain.tld:5000
EOF

# need to get the project.conf in there

# need to get the site.conf in there


#bash -c "$(pwd)/deployment/up.sh"

lxc project switch default
