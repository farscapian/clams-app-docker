#!/bin/bash

set -exu

PROJECTS_CONF_PATH="$HOME/ss/projects"
REMOTE_CONF_PATH="$HOME/ss/remotes/$(incus remote get-default)"
mkdir -p "$REMOTE_CONF_PATH" > /dev/null
REMOTE_CONF_FILE_PATH="$REMOTE_CONF_PATH/remote.conf"
export REMOTE_CONF_FILE_PATH="$REMOTE_CONF_FILE_PATH"

PROJECT_NAME="${SLOT}"
export PROJECT_NAME="$PROJECT_NAME"

# need to get the project.conf in there
PROJECT_CONF_PATH="$PROJECTS_CONF_PATH/$PROJECT_NAME"
export PROJECT_CONF_PATH="$PROJECT_CONF_PATH"
mkdir -p "$PROJECT_CONF_PATH"
PROJECT_CONF_FILE_PATH="$PROJECT_CONF_PATH/project.conf"
export PROJECT_CONF_FILE_PATH="$PROJECT_CONF_FILE_PATH"

# the LNPLAY_HOSTNAME should be the first availabe slot.
LNPLAY_HOSTNAME="$SLOT"
export LNPLAY_HOSTNAME="$LNPLAY_HOSTNAME"

# todo I think I need to make this optional in Sovereign Stack.
# no need for us to define a parameters relevant to www only.
# now we need to stub out the site.conf file.
SITES_PATH="$HOME/ss/sites"
SITES_CONF_PATH="$SITES_PATH/$LNPLAY_CLUSTER_UNDERLAY_DOMAIN"
mkdir -p "$SITES_CONF_PATH"
SITE_CONF_PATH="$SITES_CONF_PATH/site.conf"
export SITE_CONF_PATH="$SITE_CONF_PATH"

LNPLAY_CONF_PATH="$SITES_CONF_PATH/$LNPLAY_HOSTNAME.$LNPLAY_CLUSTER_UNDERLAY_DOMAIN"
export LNPLAY_CONF_PATH="$LNPLAY_CONF_PATH"
mkdir -p "$LNPLAY_CONF_PATH"
LNPLAY_ENV_FILE_PATH="$LNPLAY_CONF_PATH/lnplay.conf"
export LNPLAY_ENV_FILE_PATH="$LNPLAY_ENV_FILE_PATH"
