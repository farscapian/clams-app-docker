#!/bin/bash

set -exu

# Now let's clean up all the projects from the cluster.
PROJECT_NAMES=$(lxc project list --format csv -q | grep -vw default | cut -d',' -f1)

# Iterate over each project name
for OLD_PROJECT_NAME in $PROJECT_NAMES; do
    if ! echo "$OLD_PROJECT_NAME" | grep -q default; then
        if ! echo "$OLD_PROJECT_NAME" | grep -q current; then
            echo "Deprovisioning project '$OLD_PROJECT_NAME'" >> /dev/null
            lxc project switch "$OLD_PROJECT_NAME"

            PROJECT_CONF_FILE_PATH="$PROJECTS_CONF_PATH/$OLD_PROJECT_NAME/project.conf"
            if [ -f "$PROJECT_CONF_FILE_PATH" ]; then
                env PURGE_STORAGE_VOLUMES="$PURGE_STORAGE_VOLUMES" bash -c "/sovereign-stack/deployment/down.sh -f"
            fi

            lxc project switch default >> /dev/null
            lxc project delete "$OLD_PROJECT_NAME" >> /dev/null
        fi
    fi
done

if [ "$PURGE_BASE_IMAGE" = true ]; then
    if lxc image list -q --format csv | grep -q ss-docker-jammy-40; then
        lxc image delete ss-docker-jammy-40
    fi
fi

rm -rf "$HOME/ss"

# # set the project to default
# lxc project switch default > /dev/null

# echo "" > "$HOME/.ssh/known_hosts"