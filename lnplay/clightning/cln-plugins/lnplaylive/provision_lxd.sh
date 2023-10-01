#!/bin/bash

set -eu

PROVISION_NEW_PROJECT=true
DEPROVISION_PROJECTS=false

INVOICE_ID=
EXPIRATION_DATE_UNIX_TIMESTAMP=
NODE_COUNT=

# grab any modifications from the command line.
for i in "$@"; do
    case $i in
        --invoice-id=*)
            INVOICE_ID="${i#*=}"
            shift
        ;;
        --expiration-date=*)
            EXPIRATION_DATE_UNIX_TIMESTAMP="${i#*=}"
            shift
        ;;
        --node-count=*)
            NODE_COUNT="${i#*=}"
            shift
        ;;
        *)
        echo "Unexpected option: $1"
        exit 1
        ;;
    esac
done

if [ -z "$NODE_COUNT" ]; then
    echo "ERROR: Node count must be set."
    exit 1
fi

if [ "$NODE_COUNT" != 8 ] && [ "$NODE_COUNT" != 16 ]; then
    echo "ERROR: Node count MUST be 8 or 16."
    exit 1
fi

if [ -z "$INVOICE_ID" ]; then
    echo "ERROR: INVOICE_ID must be set."
    exit 1
fi

if [ -z "$EXPIRATION_DATE_UNIX_TIMESTAMP" ]; then
    echo "ERROR: EXPIRATION_DATE_UNIX_TIMESTAMP must be set."
    exit 1
fi


# function - objective is to get the next available slot.
HOST_MAPPINGS="$HOME/host_mappings.csv"

# Extract the first column of the csv. These represental total available slots.
ALL_SLOTS=$(cut -d, -f1 < "$HOST_MAPPINGS")

# next, we get a list of all those slots which are currently allocated.
USED_SLOTS_LIST=$(lxc project list --format csv | grep -v default | cut -d, -f1 | sed 's/ (current)//g' | cut -d- -f1)

# Convert arrays to sorted files
printf "%s\n" "${ALL_SLOTS[@]}" | sort > "$HOME"/setA.txt
printf "%s\n" "${USED_SLOTS_LIST[@]}" | sort > "$HOME"/setB.txt

FIRST_AVAILABLE_SLOT=
AVAILABLE_SLOTS=
if grep -vxF -f "$HOME"/setB.txt "$HOME"/setA.txt >> /dev/null; then
    AVAILABLE_SLOTS=$(grep -vxF -f "$HOME"/setB.txt "$HOME"/setA.txt)
    if [ -n "$AVAILABLE_SLOTS" ]; then
        SEARCH_PATTERN="$(printf "%03d\n" "$NODE_COUNT")slot"
        SLOTS_MATCHING_PRODUCT=$(echo "$AVAILABLE_SLOTS" | grep "$SEARCH_PATTERN")
        FIRST_AVAILABLE_SLOT=$(echo "$SLOTS_MATCHING_PRODUCT" | grep -wv Hostname | head -n 1)
    fi
fi

lxc project switch default

PROJECTS_CONF_PATH="$HOME/ss/projects"

# we only provision if there's a slot available.
if [ -n "$FIRST_AVAILABLE_SLOT" ] && [ "$PROVISION_NEW_PROJECT" = true ]; then
    REMOTE_CONF_PATH="$HOME/ss/remotes/$(lxc remote get-default)"
    mkdir -p "$REMOTE_CONF_PATH" > /dev/null

    REMOTE_CONF_FILE_PATH="$REMOTE_CONF_PATH/remote.conf"

    # need to get the remote.conf in there
    # this isn't really needed since env are provided via docker.
    cat > "$REMOTE_CONF_FILE_PATH" <<EOF
LXD_REMOTE_PASSWORD=
# DEPLOYMENT_STRING=
# REGISTRY_URL=http://registry.domain.tld:5000
EOF


# get the short invoice id since lxc does'nt support long project names.
INVOICE_SHORT_ID=$(echo -n "$INVOICE_ID" | sha256sum | cut -d' ' -f1)
LOWER_ID="${INVOICE_SHORT_ID: -6}"
PROJECT_NAME="${FIRST_AVAILABLE_SLOT}-${LOWER_ID^^}-$EXPIRATION_DATE_UNIX_TIMESTAMP"

# need to get the project.conf in there
PROJECTS_CONF_PATH="$HOME/ss/projects"
PROJECT_CONF_PATH="$PROJECTS_CONF_PATH/$PROJECT_NAME"
mkdir -p "$PROJECT_CONF_PATH"

PROJECT_CONF_FILE_PATH="$PROJECT_CONF_PATH/project.conf"

# the LNPLAY_HOSTNAME should be the first availabe slot.
LNPLAY_HOSTNAME="$FIRST_AVAILABLE_SLOT"

HOST_CSV=$(< "$HOST_MAPPINGS")
VM_MAC_ADDRESS=$(echo "$HOST_CSV" | grep "$LNPLAY_HOSTNAME" | cut -d',' -f2)

# stub out the project.conf
cat > "$PROJECT_CONF_FILE_PATH" <<EOF
PRIMARY_DOMAIN="${DOMAIN_NAME}"
LNPLAY_SERVER_MAC_ADDRESS=${VM_MAC_ADDRESS}
LNPLAY_SERVER_HOSTNAME=${LNPLAY_HOSTNAME}
EOF

# now let's create the project
if ! lxc project list | grep -q "$PROJECT_NAME"; then
    lxc project create -q "$PROJECT_NAME"
    lxc project set "$PROJECT_NAME" features.networks=true features.images=false features.storage.volumes=true
    lxc project switch -q "$PROJECT_NAME"
fi


    # now we need to stub out the site.conf file.
    SITES_CONF_PATH="$HOME/ss/sites/$LNPLAY_CLUSTER_UNDERLAY_DOMAIN"
    mkdir -p "$SITES_CONF_PATH"
    SITE_CONF_PATH="$SITES_CONF_PATH/site.conf"
    cat > "$SITE_CONF_PATH" <<EOF
DOMAIN_NAME=${LNPLAY_CLUSTER_UNDERLAY_DOMAIN}
DEPLOY_GHOST=false
DEPLOY_NEXTCLOUD=false
DEPLOY_NOSTR=false
NOSTR_ACCOUNT_PUBKEY=
DEPLOY_GITEA=false
EOF

    bash -c "/sovereign-stack/deployment/up.sh"

fi

if [ "$DEPROVISION_PROJECTS" = true ]; then

# Iterate over each project name
for OLD_PROJECT_NAME in $PROJECT_NAMES; do
    if ! echo "$OLD_PROJECT_NAME" | grep -q default; then
        if ! echo "$OLD_PROJECT_NAME" | grep -q current; then
            lxc project switch "$OLD_PROJECT_NAME"
            if [ -f "$PROJECT_CONF_FILE_PATH" ]; then
                bash -c "/sovereign-stack/deployment/down.sh --purge -f" || true
            fi

            lxc project switch default
            lxc project delete "$OLD_PROJECT_NAME" >> /dev/null
        fi
    fi
done

# set the project to default
lxc project switch default  > /dev/null

fi

# set the remote to local.
lxc remote switch local  > /dev/null
