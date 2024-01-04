#!/bin/bash

set -eu

# Now let's clean up all the projects from the cluster.
PROJECT_NAMES=$(incus project list --format csv -q | grep -vw default | cut -d',' -f1)

# Iterate over each project name
for OLD_PROJECT_NAME in $PROJECT_NAMES; do
    if ! echo "$OLD_PROJECT_NAME" | grep -q default; then
        if ! echo "$OLD_PROJECT_NAME" | grep -q current; then

            SLOT="$OLD_PROJECT_NAME"
            export SLOT="$SLOT"

            source "$PLUGIN_PATH/lnplaylive/lnplaylive.sh"

            incus project switch "$SLOT"

            INSTANCE=$(incus list --format csv -q --columns n)
            if [ -n "$INSTANCE" ]; then
                incus delete -f "$INSTANCE"
            fi

            PROFILE=$(incus profile list -q --format csv | grep -v "default," | cut -d',' -f1)
            if [ -n "$PROFILE" ]; then
                incus profile delete "$PROFILE"
            fi

            incus project switch default >> /dev/null
            ssh-keygen -R "${INSTANCE//-/.}"
            incus project delete "$SLOT" >> /dev/null
        fi
    fi
done

rm -rf "$HOME/ss"

# set the project to default
incus project switch default > /dev/null

echo "" > "$HOME/.ssh/known_hosts"