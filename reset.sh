#!/bin/bash

set -eu
cd "$(dirname "$0")"

./down.sh "$@"

./up.sh "$@"
