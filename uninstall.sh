#!/bin/bash

# this script just uninstalls docker engine. 

sudo apt purge -y docker-ce containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras dnsutils gridsite-clients qrencode

# no need to remove docker-ce-cli