#!/bin/bash

set -e
cd "$(dirname "$0")"

RPC_AUTH_TOKEN=$(docker run --rm -t "$PYTHON_IMAGE" /scripts/rpc-auth.py "$BITCOIND_RPC_USERNAME" "$BITCOIND_RPC_PASSWORD" | grep rpcauth)
RPC_AUTH_TOKEN="${RPC_AUTH_TOKEN//[$'\t\r\n ']}"

BITCOIND_COMMAND="bitcoind -server=1 -${RPC_AUTH_TOKEN} -upnp=0 -rpcbind=0.0.0.0 -rpcallowip=0.0.0.0/0 -rpcport=18443 -rest -listen=1 -listenonion=0 -fallbackfee=0.0002 -mempoolfullrbf=1"

for CHAIN in regtest signet; do
    if [ "$CHAIN" = "$BTC_CHAIN" ]; then
        BITCOIND_COMMAND="$BITCOIND_COMMAND -${BTC_CHAIN}"
    fi
done

if [ "$BTC_CHAIN" = mainnet ]; then
    BITCOIND_COMMAND="${BITCOIND_COMMAND} -dbcache=512 -assumevalid=000000000000000000035c5d77449f404b15de2c1662b48b241659e92d3daa14"
fi

cat > "$DOCKER_COMPOSE_YML_PATH" <<EOF
version: '3.8'
services:

  reverse-proxy:
    image: ${NGINX_DOCKER_IMAGE_NAME}
EOF


cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF
    ports:
      - 80:80
EOF

if [ "$ENABLE_TLS" = true ]; then
    cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF
      - 443:443
EOF
fi

# these are the ports for the websocket connections.
for (( CLN_ID=0; CLN_ID<CLN_COUNT; CLN_ID++ )); do
    CLN_WEBSOCKET_PORT=$(( STARTING_WEBSOCKET_PORT+CLN_ID ))
    cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF
      - ${CLN_WEBSOCKET_PORT}:${CLN_WEBSOCKET_PORT}
EOF
done

cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF
    networks:
      - nginxnet
EOF

if [ "$BTC_CHAIN" != regtest ]; then
    for (( CLN_ID=0; CLN_ID<CLN_COUNT; CLN_ID++ )); do
cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF
      - clnnet-${CLN_ID}
EOF
    done
fi


if [ "$DEPLOY_PRISM_BROWSER_APP" = true ]; then
cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF
      - prism-appnet
EOF
fi


cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF
    configs:
      - source: nginx-config
        target: /etc/nginx/nginx.conf
EOF

if [ "$DEPLOY_CLAMS_BROWSER_APP" = true ] || [ "$ENABLE_TLS" = true ]; then
    cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF
    volumes:
EOF
fi

if [ "$DEPLOY_CLAMS_BROWSER_APP" = true ]; then
    cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF
      - clams-browser-app:/browser-app
EOF
fi

if [ "$ENABLE_TLS" = true ]; then
    cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF
      - certs:/certs
EOF
fi




if [ "$DEPLOY_PRISM_BROWSER_APP" = true ]; then
    cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF

  prism-browser-app:
    image: ${PRISM_APP_IMAGE_NAME}
    networks:
      - prism-appnet
    environment:
      - HOST=0.0.0.0
      - PORT=5173
    command: >-
      npm run dev -- --host
    deploy:
      mode: global
EOF

fi


cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF

  bitcoind:
    image: ${BITCOIND_DOCKER_IMAGE_NAME}
    hostname: bitcoind
    networks:
      - bitcoindnet
    command: >-
      ${BITCOIND_COMMAND}
EOF

# we persist data for signet, testnet, and mainnet
cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF
    volumes:
      - bitcoind-${BTC_CHAIN}:/home/bitcoin/.bitcoin
EOF


cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF
    deploy:
      mode: global

EOF

############ BITCOIND MANAGER SERVICE
if [ "$BTC_CHAIN" == regtest ]; then
    cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF

  roygbiv-manager:
    image: ${BITCOIND_MANAGER_IMAGE_NAME}
    hostname: roygbiv-manager
    networks:
      - bitcoindnet
    environment: 
      - BLOCK_TIME=${REGTEST_BLOCK_TIME:-15}
      - BITCOIND_SERVICE_NAME=bitcoind
      - BITCOIND_RPC_USERNAME=${BITCOIND_RPC_USERNAME}
      - BITCOIND_RPC_PASSWORD=${BITCOIND_RPC_PASSWORD}
    deploy:
      mode: global
      
EOF
fi

##############################
cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF
networks:
  bitcoindnet:
    attachable: true
EOF


cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF
  nginxnet:
    attachable: true
EOF

if [ "$BTC_CHAIN" != regtest ]; then
    for (( CLN_ID=0; CLN_ID<CLN_COUNT; CLN_ID++ )); do
cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF
  clnnet-${CLN_ID}:
EOF
    done
fi

if [ "$DEPLOY_PRISM_BROWSER_APP" = true ]; then
cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF
  prism-appnet:
EOF
fi


cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF

volumes:
EOF

cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF

  bitcoind-${BTC_CHAIN}:
EOF


if [ "$DEPLOY_CLAMS_BROWSER_APP" = true ]; then
    cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF

  clams-browser-app:
    external: true
    name: clams-browser-app
EOF
fi

if [ "$ENABLE_TLS" = true ]; then
    cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF
  certs:
    external: true
    name: roygbiv-certs
EOF
fi

cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF

configs:
  nginx-config:
    file: ${NGINX_CONFIG_PATH}

EOF

