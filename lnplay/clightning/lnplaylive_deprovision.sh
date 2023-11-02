#!/bin/bash

set -exu

# Now let's clean up all the projects from the cluster.
PROJECT_NAMES=$(lxc project list --format csv -q | grep -vw default | cut -d',' -f1)

# Iterate over each project name
for OLD_PROJECT_NAME in $PROJECT_NAMES; do
    if ! echo "$OLD_PROJECT_NAME" | grep -q default; then
        if ! echo "$OLD_PROJECT_NAME" | grep -q current; then

            SLOT="$OLD_PROJECT_NAME"
            export SLOT="$SLOT"

            source "$PLUGIN_PATH/lnplaylive/lnplaylive.sh"

            lxc project switch "$SLOT"

            INSTANCE=$(lxc list --format csv -q --columns n)
            if [ -n "$INSTANCE" ]; then
                lxc delete -f "$INSTANCE"
            fi

            PROFILE=$(lxc profile list -q --format csv | grep -v "default," | cut -d',' -f1)
            if [ -n "$PROFILE" ]; then
                lxc profile delete "$PROFILE"
            fi

            lxc project switch default >> /dev/null
            ssh-keygen -R "${INSTANCE//-/.}"
            lxc project delete "$SLOT" >> /dev/null
        fi
    fi
done

rm -rf "$HOME/ss"

# set the project to default
lxc project switch default > /dev/null

echo "" > "$HOME/.ssh/known_hosts"