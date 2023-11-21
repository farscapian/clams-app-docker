#!/bin/bash

set -eu
cd "$(dirname "$0")"

INVOICE_ID=
EXPIRATION_DATE_UNIX_TIMESTAMP=
NODE_COUNT=

# the slot we provision to is passed in. This is needed
# so we can coordinate the issuing of invoices via the cln database
# when the slots are full, the db says itemx is unavaialbe and thus won't issue invoices.
SLOT=
VM_MAC_ADDRESS=
STARTING_EXTERNAL_PORT=
CONNECTION_STRINGS_PATH=

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
        --slot=*)
            SLOT="${i#*=}"
            shift
        ;;
        --mac-addr=*)
            VM_MAC_ADDRESS="${i#*=}"
            shift
        ;;
        --starting-ext-port=*)
            STARTING_EXTERNAL_PORT="${i#*=}"
            shift
        ;;
        --connection-strings-path=*)
            CONNECTION_STRINGS_PATH="${i#*=}"
            shift
        ;;
        *)
        echo "Unexpected option: $1"
        exit 1
        ;;
    esac
done

if [ -z "$CONNECTION_STRINGS_PATH" ]; then
    echo "ERROR: CONNECTION_STRINGS_PATH was not set."
    exit 1
fi

export CONNECTION_STRINGS_PATH="$CONNECTION_STRINGS_PATH"

if [ -z "$SLOT" ]; then
    echo "ERROR: The SLOT MUST be defined when calling this script."
    exit 1
fi

if [ -z "$NODE_COUNT" ]; then
    echo "ERROR: Node count must be set."
    exit 1
fi

LNPLAY_SERVER_CPU_COUNT=
LNPLAY_SERVER_MEMORY_MB=
if [ "$NODE_COUNT" = 8 ]; then
    LNPLAY_SERVER_CPU_COUNT=2
    LNPLAY_SERVER_MEMORY_MB=1224
elif [ "$NODE_COUNT" = 16 ]; then
    LNPLAY_SERVER_CPU_COUNT=2
    LNPLAY_SERVER_MEMORY_MB=2048
elif [ "$NODE_COUNT" = 24 ]; then
    LNPLAY_SERVER_CPU_COUNT=4
    LNPLAY_SERVER_MEMORY_MB=3072
elif [ "$NODE_COUNT" = 32 ]; then
    LNPLAY_SERVER_CPU_COUNT=4
    LNPLAY_SERVER_MEMORY_MB=4096
else
    echo "ERROR: Node count MUST be 8, 16, 24, or 32."
    exit 1
fi

if [ -z "$INVOICE_ID" ]; then
    echo "ERROR: INVOICE_ID must be set."
    exit 1
fi

# TODO do some sanity checks on the expiration date.
if [ -z "$EXPIRATION_DATE_UNIX_TIMESTAMP" ]; then
    echo "ERROR: The VM expiration date must be set."
    exit 1
fi

export INVOICE_ID="$INVOICE_ID"
export LNPLAY_SERVER_CPU_COUNT="$LNPLAY_SERVER_CPU_COUNT"
export LNPLAY_SERVER_MEMORY_MB="$LNPLAY_SERVER_MEMORY_MB"
export VM_MAC_ADDRESS="$VM_MAC_ADDRESS"
export STARTING_EXTERNAL_PORT="$STARTING_EXTERNAL_PORT"
export NODE_COUNT="$NODE_COUNT"
export SLOT="$SLOT"

# generate source files and get environment variables.
. ./lnplaylive.sh

./stub_confs.sh

# now let's create the project
if ! incus project list | grep -q "$PROJECT_NAME"; then
    incus project create -q "$PROJECT_NAME"
    incus project set "$PROJECT_NAME" features.networks=true features.images=false features.storage.volumes=false
    incus project switch -q "$PROJECT_NAME"
fi

# ok, now that our sovereign stack .conf files are in place, we can run the up script.
bash -c "/sovereign-stack/deployment/up.sh  \
            --lnplay-env-path=$LNPLAY_ENV_FILE_PATH \
            --vm-expiration-date=$EXPIRATION_DATE_UNIX_TIMESTAMP \
            --order-id=$INVOICE_ID"
