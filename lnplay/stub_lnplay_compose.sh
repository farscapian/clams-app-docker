#!/bin/bash

set -eu
cd "$(dirname "$0")"

BITCOIND_RPC_THREADS=$(( CLN_COUNT*4 ))
BITCOIND_WORKQUEUE=$(( CLN_COUNT*16 ))

BITCOIND_COMMAND="bitcoind -rpccookiefile=/bitcoind-cookie/.cookie -server=1 -upnp=0 -rpcbind=0.0.0.0 -rpcallowip=0.0.0.0/0 -rpcport=18443 -rest -listen=1 -listenonion=0 -fallbackfee=0.0002 -rpcthreads=$BITCOIND_RPC_THREADS -rpcworkqueue=${BITCOIND_WORKQUEUE}"

for CHAIN in regtest signet; do
    if [ "$CHAIN" = "$BTC_CHAIN" ]; then
        BITCOIND_COMMAND="$BITCOIND_COMMAND -${BTC_CHAIN}"
    fi
done

if [ "$ENABLE_BITCOIND_DEBUGGING_OUTPUT" = true ]; then
    BITCOIND_COMMAND="$BITCOIND_COMMAND -debug=1"
fi


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
      - ${BROWSER_APP_EXTERNAL_PORT}:80
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



# these are the ports for the websocket connections.
REST_PORT=
for (( CLN_ID=0; CLN_ID<CLN_COUNT; CLN_ID++ )); do
    REST_PORT=$(( STARTING_REST_PORT+CLN_ID ))
    cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF
      - ${REST_PORT}:${REST_PORT}
EOF
done

cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF
    networks:
      - nginxnet
EOF


if [ "$DEPLOY_CLAMS_REMOTE" = true ]; then
    cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF
      - clams-appnet
EOF
fi

if [ "$BTC_CHAIN" != regtest ]; then
    for (( CLN_ID=0; CLN_ID<CLN_COUNT; CLN_ID++ )); do
cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF
      - clnnet-${CLN_ID}
EOF
    done
fi

cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF
    configs:
      - source: nginx-config
        target: /etc/nginx/nginx.conf
EOF

cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF
    volumes:
EOF

cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF
      - lnplay-certs:/certs
EOF

if [ "$DEPLOY_CLAMS_REMOTE" = true ]; then
    cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF

  clams-remote:
    image: ${CLAMS_REMOTE_IMAGE_NAME}
    networks:
      - clams-appnet
    environment:
      - HOST=0.0.0.0
      - PORT=5173
    deploy:
      mode: global
      resources:
        limits:
          cpus: '2'
          memory: 1000M

EOF

fi


cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF

  bitcoind:
    image: ${BITCOIND_DOCKER_IMAGE_NAME}
    hostname: bitcoind
    networks:
      - bitcoindnet
    environment:
      - BTC_CHAIN=${BTC_CHAIN}
    command: >-
      ${BITCOIND_COMMAND}
    volumes:
      - bitcoind-${BTC_CHAIN}:/home/bitcoin/.bitcoin
      - ${COOKIE_DOCKER_VOL}:/bitcoind-cookie:rw
    deploy:
      mode: global
EOF

############ BITCOIND MANAGER SERVICE
if [ "$BTC_CHAIN" == regtest ]; then
    cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF

  lnplay-manager:
    image: ${BITCOIND_MANAGER_IMAGE_NAME}
    hostname: lnplay-manager
    networks:
      - bitcoindnet
    environment: 
      - BLOCK_TIME=${REGTEST_BLOCK_TIME:-15}
      - BITCOIND_SERVICE_NAME=bitcoind
    volumes:
      - ${COOKIE_DOCKER_VOL}:/bitcoind-cookie
    deploy:
      mode: global
      resources:
        limits:
          cpus: '1'
          memory: 100M
      
EOF
fi

##############################
cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF
networks:
  bitcoindnet:
    attachable: true
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

if [ "$DEPLOY_CLAMS_REMOTE" = true ]; then
cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF
  clams-appnet:
EOF
fi


cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF

volumes:

  bitcoind-${BTC_CHAIN}:
  ${COOKIE_DOCKER_VOL}:
    external: true

EOF


cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF
  lnplay-certs:
    external: true
    name: lnplay-certs

EOF

cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF
configs:
  nginx-config:
    file: ${NGINX_CONFIG_PATH}

EOF

