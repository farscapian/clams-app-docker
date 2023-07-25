#!/bin/bash


set -eu
cd "$(dirname "$0")"

readarray -t names < ./names.txt

# write out service for CLN; style is a docker stack deploy style,
# so we will use the replication feature

for (( CLN_ID=0; CLN_ID<CLN_COUNT; CLN_ID++ )); do
    DOCKER_COMPOSE_YML_PATH=$(pwd)/stacks/cln-${CLN_ID}.yml

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

    CLN_WEBSOCKET_PORT=$(( STARTING_WEBSOCKET_PORT+CLN_ID ))
    CLN_PTP_PORT=$(( STARTING_CLN_PTP_PORT+CLN_ID ))

    CLN_COMMAND="sh -c \"chown 1000:1000 /opt/c-lightning-rest/certs && lightningd --alias=${CLN_ALIAS} --bind-addr=0.0.0.0:9735 --bitcoin-rpcuser=${BITCOIND_RPC_USERNAME} --bitcoin-rpcpassword=${BITCOIND_RPC_PASSWORD} --bitcoin-rpcconnect=bitcoind --bitcoin-rpcport=18443 --experimental-websocket-port=9736 --plugin=/opt/c-lightning-rest/plugin.js --experimental-offers --experimental-dual-fund --experimental-onion-messages --experimental-peer-storage"

    if [ "$ENABLE_TOR" = true ]; then
        CLN_COMMAND="${CLN_COMMAND} --proxy=torproxy-${CLN_NAME}:9050"
    fi

    # if we're NOT in development mode, we go ahead and bake
    #  the existing prism-plugin.py into the docker image.
    # otherwise we will mount the path later down the road so
    # plugins can be reloaded quickly without restarting the whole thing.
    if [ "$DOMAIN_NAME" != "127.0.0.1" ]; then
        CLN_COMMAND="$CLN_COMMAND --plugin=/plugins/prism-plugin.py"
    fi

    # mainnet only
    if [ -n "$CLN_P2P_PORT_OVERRIDE" ]; then
        CLN_PTP_PORT="$CLN_P2P_PORT_OVERRIDE"
    fi

    if [ "$BTC_CHAIN" = mainnet ]; then
        CLN_COMMAND="$CLN_COMMAND --announce-addr=${DOMAIN_NAME}:${CLN_PTP_PORT} --announce-addr-dns=true"
    fi

    if [ "$BTC_CHAIN" = signet ]; then
        # signet only
        CLN_COMMAND="$CLN_COMMAND --network=${BTC_CHAIN}"
        CLN_COMMAND="$CLN_COMMAND --announce-addr=${DOMAIN_NAME}:${CLN_PTP_PORT} --announce-addr-dns=true"
    fi

    if [ "$BTC_CHAIN" = regtest ]; then
        # regtest only
        CLN_COMMAND="$CLN_COMMAND --network=${BTC_CHAIN}"
        CLN_COMMAND="$CLN_COMMAND --announce-addr=${CLN_NAME}:9735 --announce-addr-dns=true"
        CLN_COMMAND="$CLN_COMMAND --dev-fast-gossip"

        # todo make the poll value proportional to 
        # CLN node count. That is, more nodes, the higher the value.
        #CLN_COMMAND="$CLN_COMMAND --dev-bitcoind-poll=5"
        # CLN_COMMAND="$CLN_COMMAND --funder-policy=match"
        # CLN_COMMAND="$CLN_COMMAND --funder-policy-mod=100"
        # CLN_COMMAND="$CLN_COMMAND --funder-min-their-funding=10000"
        # CLN_COMMAND="$CLN_COMMAND --funder-per-channel-max=100000"
        # CLN_COMMAND="$CLN_COMMAND --funder-fuzz-percent=0"
        # CLN_COMMAND="$CLN_COMMAND --lease-fee-basis=50"
        # CLN_COMMAND="$CLN_COMMAND --lease-fee-base-sat=2sat"
        # CLN_COMMAND="$CLN_COMMAND --allow-deprecated-apis=false"
        CLN_COMMAND="$CLN_COMMAND --fee-base=1"
        CLN_COMMAND="$CLN_COMMAND --fee-per-satoshi=1"
    fi

    if [ "$ENABLE_DEBUGGING_OUTPUT" = true ]; then
        CLN_COMMAND="$CLN_COMMAND --log-level=debug"
    fi

    # the CLN poll interval should grow linearly with CLN_COUNT.
    # Right now we reserve 1 second for every 10 CLN nodes there are.
    # so if you're running 160 nodes, it'll take 16 seconds for all the
    # CLN nodes to come into consensus.
    SECONDS_PER_TEN_NODES=1
    CLN_POLL_INTERVAL_SECONDS=$(( (CLN_COUNT+11) / 10 ))
    CLN_COMMAND="$CLN_COMMAND --dev-bitcoind-poll=$((SECONDS_PER_TEN_NODES * CLN_POLL_INTERVAL_SECONDS ))"

    CLN_COMMAND="$CLN_COMMAND\""
    cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF
  cln-${CLN_ID}:
    image: ${CLN_IMAGE_NAME}
    hostname: cln-${CLN_ID}
    command: >-
      ${CLN_COMMAND}
EOF

    cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF
    environment:
      - RPC_PATH=${RPC_PATH}
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
      resources:
        limits:
          cpus: '2'
          memory: 150M
        #reservations:
        #  cpus: '0.2'
        #  memory: 100M

EOF


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
    sleep 0.5

done
