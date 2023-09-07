#!/bin/bash

set -eu
cd "$(dirname "$0")"

RPC_AUTH_TOKEN=$(docker run --rm -t "$CLN_PYTHON_IMAGE_NAME" /scripts/rpc-auth.py "$BITCOIND_RPC_USERNAME" "$BITCOIND_RPC_PASSWORD" | grep rpcauth)
RPC_AUTH_TOKEN="${RPC_AUTH_TOKEN//[$'\t\r\n ']}"
BITCOIND_RPC_THREADS=$(( CLN_COUNT*4 ))
BITCOIND_WORKQUEUE=$(( CLN_COUNT*16 ))

BITCOIND_COMMAND="bitcoind -server=1 -${RPC_AUTH_TOKEN} -upnp=0 -rpcbind=0.0.0.0 -rpcallowip=0.0.0.0/0 -rpcport=18443 -rest -listen=1 -listenonion=0 -fallbackfee=0.0002 -mempoolfullrbf=1 -rpcthreads=$BITCOIND_RPC_THREADS -rpcworkqueue=${BITCOIND_WORKQUEUE}"

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

cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF
    networks:
      - nginxnet
EOF


# if [ "$DEPLOY_LNPLAYLIVE_FRONTEND" = true ]; then
#     cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF
#       - lnplaylive-appnet
# EOF
# fi


if [ "$DEPLOY_CLAMS_BROWSER_APP" = true ]; then
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

if [ "$ENABLE_TLS" = true ] || [ "$DEPLOY_LNPLAYLIVE_FRONTEND" = true ]; then

    cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF
    volumes:
EOF
    

    if [ "$ENABLE_TLS" = true ]; then
        cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF
      - certs:/certs
EOF
    fi

    if [ "$DEPLOY_LNPLAYLIVE_FRONTEND" = true ]; then
        cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF
      - lnplaylive:/lnplaylive
EOF
    fi
fi

if [ "$DEPLOY_CLAMS_BROWSER_APP" = true ]; then
    cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF

  clams-app:
    image: ${CLAMS_APP_IMAGE_NAME}
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

# elif [ "$DEPLOY_LNPLAYLIVE_FRONTEND" = true ]; then
#     cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF

#   lnplaylive-app:
#     image: ${LNPLAYLIVE_IMAGE_NAME}
#     networks:
#       - lnplaylive-appnet
#     environment:
#       - HOST=0.0.0.0
#       - PORT=5173

# EOF

elif [ "$DEPLOY_PRISM_BROWSER_APP" = true ]; then
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
      resources:
        limits:
          cpus: '2'
          memory: 500M
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
    volumes:
      - bitcoind-${BTC_CHAIN}:/home/bitcoin/.bitcoin
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
      - BITCOIND_RPC_USERNAME=\${BITCOIND_RPC_USERNAME}
      - BITCOIND_RPC_PASSWORD=\${BITCOIND_RPC_PASSWORD}
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

if [ "$DEPLOY_CLAMS_BROWSER_APP" = true ]; then
cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF
  clams-appnet:
EOF
fi

if [ "$DEPLOY_PRISM_BROWSER_APP" = true ]; then
cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF
  prism-appnet:
EOF
fi

# if [ "$DEPLOY_LNPLAYLIVE_FRONTEND" = true ]; then
# cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF
#   lnplaylive-appnet:
# EOF
# fi



cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF

volumes:
  bitcoind-${BTC_CHAIN}:
EOF

if [ "$DEPLOY_LNPLAYLIVE_FRONTEND" = true ]; then

cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF
  lnplaylive:
    external: true
    name: lnplaylive
EOF
fi


if [ "$ENABLE_TLS" = true ]; then
    cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF
  certs:
    external: true
    name: lnplay-certs
EOF
fi

cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF

configs:
  nginx-config:
    file: ${NGINX_CONFIG_PATH}

EOF

