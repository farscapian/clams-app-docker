#!/bin/bash

set -eux
cd "$(dirname "$0")"

. ./defaults.env
. ./load_env.sh

PURGE=false
WITH_TESTS=false
RETAIN_CACHE=false

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
        --retain-cache)
            RETAIN_CACHE=true
        ;;
        *)
        ;;
    esac
done

if [[ "${PURGE^^}" == "TRUE" && "${RETAIN_CACHE^^}" == "TRUE" ]]; then
  echo "Error: cannot set --purge and --retain-cache to true. Pick one."
  exit 1
fi

bash -c "./down.sh --purge=$PURGE"

sleep 10

bash -c "./up.sh --with-tests=$WITH_TESTS --retain-cache=$RETAIN_CACHE"