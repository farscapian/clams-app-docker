#! /bin/bash

# TODO let's first do a sanity check to ensure the 
# lightning nodes actually have access to the prism api
set -eu
cd "$(dirname "$0")"

echo "INFO: starting test_prism_plugin.sh."

./create_prism.sh

echo -e "\033[1A\033[2K"
echo "All prism plugin tests passed. YAY!"
