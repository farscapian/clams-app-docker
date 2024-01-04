#!/bin/bash

set -exu

if [ "$UID" != 0 ]; then
    echo "ERROR: this script MUST be run as root."
    exit 1
fi

apt update

# needed by tehse scripts
apt install -y jq dnsutils


# the rest is needed for docker to work
apt install -y ca-certificates curl gnupg bc


install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg


echo "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt update

# we need apache2-utils for htpasswd files
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin apache2-utils

usermod -aG docker "$(whoami)"
