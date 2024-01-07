#!/bin/bash

set -eu

# let's make sure our remotes are in place prior to any provisioning.
if ! incus remote list | grep -q lnplaylive; then
    incus remote add lnplaylive -q "$LNPLAY_INCUS_FQDN_PORT" --auth-type=tls --token="$INCUS_CERT_TRUST_TOKEN" --accept-certificate >> /dev/null
fi

# switch the remote to lnplaylive
if ! incus remote get-default | grep -q lnplaylive; then
    incus remote switch lnplaylive >> /dev/null
fi

# ensure we have an SSH key to use for remote VMs.
# TODO should this mounted into the cln container?
# TODO move this to plugin start method
if [ ! -f "$HOME/.ssh/id_rsa" ]; then
    ssh-keygen -f "$HOME/.ssh/id_rsa" -t rsa -b 4096 -N "" >> /dev/null
fi

# ensure the known_hosts file exists.
KNOWN_HOSTS_FILE="$HOME/.ssh/known_hosts"
if [ ! -f "$KNOWN_HOSTS_FILE" ]; then
    touch "$KNOWN_HOSTS_FILE" >> /dev/null
fi