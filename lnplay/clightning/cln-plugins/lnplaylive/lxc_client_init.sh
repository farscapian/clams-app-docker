#!/bin/bash

set -eu

# let's make sure our remotes are in place prior to any provisioning.
if ! lxc remote list | grep -q lnplaylive; then
    lxc remote add lnplaylive -q "$LNPLAY_LXD_FQDN_PORT" --password "$LNPLAY_LXD_PASSWORD" --accept-certificate >> /dev/null
fi

if ! lxc remote get-default | grep -q lnplaylive; then
    lxc remote switch lnplaylive  > /dev/null
fi

# ensure we have an SSH key to use for remote VMs.
# TODO should this mounted into the cln container?
# TODO move this to plugin start method
if [ ! -f "$HOME/.ssh/id_rsa" ]; then
    ssh-keygen -f "$HOME/.ssh/id_rsa" -t rsa -b 4096 -N ""  > /dev/null
fi
