#!/bin/bash

set -eux
cd "$(dirname "$0")"

. ./defaults.env
. ./load_env.sh

PURGE=false
WITH_TESTS=false

# grab any modifications from the command line.
for i in "$@"; do
    case $i in
        --purge)
            PURGE=true
            shift
        ;;
        --with-tests)
            WITH_TESTS=true
        ;;
        *)
        ;;
    esac
done

bash -c "./down.sh --purge=$PURGE"

sleep 10

bash -c "./up.sh --with-tests=$WITH_TESTS"