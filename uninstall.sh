#!/bin/bash

# this script just uninstalls docker engine. 

./down.sh

sudo apt-get purge -y docker-ce containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras

# no need to remove docker-ce-cli