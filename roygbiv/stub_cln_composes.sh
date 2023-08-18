#!/bin/bash


set -eu
cd "$(dirname "$0")"

readarray -t names < "$NAMES_FILE_PATH"

# write out service for CLN; style is a docker stack deploy style,
# so we will use the replication feature

for (( CLN_ID=0; CLN_ID<CLN_COUNT; CLN_ID++ )); do
    DOCKER_COMPOSE_YML_PATH="$CLAMS_SERVER_PATH/cln-${CLN_ID}.yml"

    cat > "$DOCKER_COMPOSE_YML_PATH" <<EOF
version: '3.8'
services:

EOF

    CLN_NAME="cln-${CLN_ID}"

    # non-mainnet nodes get aliases from the names array, else domain name.
    CLN_ALIAS=""
    if [[ "$CLN_ID" -lt 200 ]]; then
        CLN_ALIAS=${names[$CLN_ID]}
    fi

    if [ "$BTC_CHAIN" = mainnet ]; then
        CLN_ALIAS="$DOMAIN_NAME"
    fi

    cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF
  cln-${CLN_ID}:
    image: ${CLN_IMAGE_NAME}
    hostname: cln-${CLN_ID}
EOF



    CLN_PTP_PORT=$(( STARTING_CLN_PTP_PORT+CLN_ID ))

    # the CLN poll interval should grow linearly with CLN_COUNT.
    # Right now we reserve 1 second for every 10 CLN nodes there are.
    # so if you're running 160 nodes, it'll take 16 seconds for all the
    # CLN nodes to come into consensus.
    SECONDS_PER_TEN_NODES=1
    CLN_POLL_INTERVAL_SECONDS=$(( (CLN_COUNT+11) / 10 ))
    BITCOIND_POLL_SETTING="$((SECONDS_PER_TEN_NODES * CLN_POLL_INTERVAL_SECONDS ))"

    cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF
    environment:
      - RPC_PATH=${RPC_PATH}
      - ENABLE_TOR=${ENABLE_TOR}
      - CLN_ALIAS=${CLN_ALIAS}
      - BITCOIND_RPC_USERNAME=\${BITCOIND_RPC_USERNAME}
      - BITCOIND_RPC_PASSWORD=\${BITCOIND_RPC_PASSWORD}
      - CLN_NAME=${CLN_NAME}
      - BTC_CHAIN=${BTC_CHAIN}
      - CLN_PTP_PORT=${CLN_PTP_PORT}
      - ENABLE_CLN_DEBUGGING_OUTPUT=${ENABLE_CLN_DEBUGGING_OUTPUT}
      - CLN_P2P_PORT_OVERRIDE=${CLN_P2P_PORT_OVERRIDE}
      - BITCOIND_POLL_SETTING=${BITCOIND_POLL_SETTING}
      - DOMAIN_NAME=${DOMAIN_NAME}
EOF

    cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF
    volumes:
      - cln-${CLN_ID}-${BTC_CHAIN}:/root/.lightning
      - cln-${CLN_ID}-certs-${BTC_CHAIN}:/opt/c-lightning-rest/certs
EOF

    if [ "$ENABLE_TOR" = true ]; then
        cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF
      - cln-${CLN_ID}-torproxy-${BTC_CHAIN}:/var/lib/tor:ro
EOF
    fi

    DEV_PLUGIN_PATH="$(pwd)/clightning/cln-plugins/bolt12-prism"
    if [ "$DOMAIN_NAME" = "127.0.0.1" ]; then
        cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF
      - ${DEV_PLUGIN_PATH}:/dev-plugins
EOF
    fi

    cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF
    networks:
      - bitcoindnet
      - nginxnet
EOF


    if [ "$ENABLE_TOR" = true ]; then
        cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF
      - torproxynet
EOF
    fi


    if [ "$BTC_CHAIN" = regtest ]; then
        cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF
      - cln-p2pnet
EOF
    fi

    if [ "$BTC_CHAIN" != regtest ]; then
        cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF
    ports:
      - ${CLN_PTP_PORT}:9735
EOF
    fi

    cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF
    deploy:
      mode: replicated
      replicas: 1
EOF

    if [ "$BTC_CHAIN" != mainnet ]; then
        cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF
      resources:
        limits:
          cpus: '2'
          memory: 240M

EOF
fi

    if [ "$ENABLE_TOR" = true ]; then

        cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF
  torproxy-cln-${CLN_ID}:
    image: ${TOR_PROXY_IMAGE_NAME}
    hostname: cln-${CLN_ID}-torproxy
    environment:
      - RPC_PATH=${RPC_PATH}
    volumes:
      - cln-${CLN_ID}-torproxy-${BTC_CHAIN}:/var/lib/tor:rw
    networks:
      - torproxynet
    deploy:
      mode: replicated
      replicas: 1

EOF

    fi



cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF

networks:
  bitcoindnet:
    external: true
    name: roygbiv-stack_bitcoindnet
EOF

    cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF
  cln-p2pnet:
    external: true
    name: roygbiv-p2pnet
EOF

    cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF

  nginxnet:
    external: true
    name: roygbiv-stack_nginxnet

EOF


    if [ "$ENABLE_TOR" = true ]; then
        cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF
  torproxynet:
EOF
    fi


    cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF

volumes:
EOF

    # define the volumes for CLN nodes. regtest and signet SHOULD NOT persist data, but TESTNET and MAINNET MUST define volumes
    cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF
  cln-${CLN_ID}-${BTC_CHAIN}:
  cln-${CLN_ID}-certs-${BTC_CHAIN}:
EOF

    if [ "$ENABLE_TOR" = true ]; then
        cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF
  cln-${CLN_ID}-torproxy-${BTC_CHAIN}:
EOF
        fi

    docker stack deploy -c "$DOCKER_COMPOSE_YML_PATH" "roygbiv-cln-${CLN_ID}"

done
