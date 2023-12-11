#!/bin/bash


set -eu
cd "$(dirname "$0")"

readarray -t names < "$NAMES_FILE_PATH"
readarray -t colors < "$COLORS_FILE_PATH"

# write out service for CLN; style is a docker stack deploy style,
# so we will use the replication feature

for (( CLN_ID=0; CLN_ID<CLN_COUNT; CLN_ID++ )); do
    DOCKER_COMPOSE_YML_PATH="$LNPLAY_SERVER_PATH/cln-${CLN_ID}.yml"

    cat > "$DOCKER_COMPOSE_YML_PATH" <<EOF
version: '3.8'
services:

EOF

    CLN_NAME="cln-${CLN_ID}"

    # non-mainnet nodes get aliases from the names array, else domain name.
    CLN_ALIAS="${names[$CLN_ID]}"

    CLN_COLOR="${colors[$CLN_ID]}"

    if [ "$BTC_CHAIN" = mainnet ]; then
        CLN_ALIAS="$DOMAIN_NAME"
    fi

    cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF
  cln-${CLN_ID}:
    image: ${CLN_IMAGE_NAME}
    hostname: cln-${CLN_ID}
EOF

    CLN_PTP_PORT=$(( STARTING_CLN_PTP_PORT+CLN_ID ))

    # the CLN poll interval should grow with CLN_COUNT.
    # This setting changes Effective Block Time (EBT). 
    # Altering this value may require updates to bitcoind's rpcworkqueue and rpcworkthreads.
    # a value of 40 here lets us target a 5 second EBT when we deploy 200 nodes (assuming REGTEST_BLOCK_TIME=5).
    # any deployments above CLN_COUNT=200 will have a longer EBT than REGTEST_BLOCK_TIME.
    CLN_POLL_RATE_NODESPERSEC=41

    # makes all calculations non-zero
    CLN_COUNT_PLUS_CLN_POLL_RATE=$((CLN_COUNT+CLN_POLL_RATE_NODESPERSEC))

    # this setting tells lightningd how often (in seconds) to check bitcoind for new blocks.
    CLN_BITCOIND_POLL_SETTING=$(( CLN_COUNT_PLUS_CLN_POLL_RATE / CLN_POLL_RATE_NODESPERSEC ))
    if [ "$CLN_BITCOIND_POLL_SETTING" = 0 ]; then
        CLN_BITCOIND_POLL_SETTING=1
    fi

    # if we're NOT in development mode, we go ahead and bake
    #  the existing prism.py into the docker image.
    # otherwise we will mount the path later down the road so
    # plugins can be reloaded quickly without restarting the whole thing.
    PLUGIN_PATH=/plugins
    if [ "$DOMAIN_NAME" = "127.0.0.1" ]; then
        PLUGIN_PATH="/cln-plugins"
    fi

    cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF
    environment:
      - ENABLE_TOR=${ENABLE_TOR}
      - CLN_ALIAS=${CLN_ALIAS}
      - CLN_COLOR=${CLN_COLOR}
      - BITCOIND_RPC_USERNAME=\${BITCOIND_RPC_USERNAME}
      - BITCOIND_RPC_PASSWORD=\${BITCOIND_RPC_PASSWORD}
      - CLN_NAME=${CLN_NAME}
      - BTC_CHAIN=${BTC_CHAIN}
      - CLN_PTP_PORT=${CLN_PTP_PORT}
      - CLN_P2P_PORT_OVERRIDE=${CLN_P2P_PORT_OVERRIDE}
      - CLN_BITCOIND_POLL_SETTING=${CLN_BITCOIND_POLL_SETTING}
      - DOMAIN_NAME=${DOMAIN_NAME}
      - DEPLOY_PRISM_PLUGIN=${DEPLOY_PRISM_PLUGIN}
      - DEPLOY_LNPLAYLIVE_PLUGIN=${DEPLOY_LNPLAYLIVE_PLUGIN}
      - LNPLAY_INCUS_FQDN_PORT=\${LNPLAY_INCUS_FQDN_PORT}
      - LNPLAY_INCUS_PASSWORD=\${LNPLAY_INCUS_PASSWORD}
      - LNPLAY_CLUSTER_UNDERLAY_DOMAIN=${LNPLAY_CLUSTER_UNDERLAY_DOMAIN}
      - LNPLAY_EXTERNAL_DNS_NAME=${LNPLAY_EXTERNAL_DNS_NAME}
      - PLUGIN_PATH=${PLUGIN_PATH}
      - DEPLOY_CLBOSS_PLUGIN=${DEPLOY_CLBOSS_PLUGIN}
EOF

    cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF
    volumes:
      - cln-${CLN_ID}-${BTC_CHAIN}:/root/.lightning
      - cln-${CLN_ID}-certs-${BTC_CHAIN}:/opt/c-lightning-rest/certs
EOF

    if [ "$DOMAIN_NAME" = "127.0.0.1" ] && [ "$DEPLOY_LNPLAYLIVE_PLUGIN" = true ]; then
        cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF
      - ${HOME}/sovereign-stack:/sovereign-stack:rw
EOF
    fi

    if [ "$ENABLE_TOR" = true ]; then
        cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF
      - cln-${CLN_ID}-torproxy-${BTC_CHAIN}:/var/lib/tor:ro
EOF
    fi

    DEV_PLUGIN_PATH="$(pwd)/clightning/cln-plugins"
    if [ "$DOMAIN_NAME" = "127.0.0.1" ]; then
        cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF
      - ${DEV_PLUGIN_PATH}:/cln-plugins
EOF
    fi

if [ "$DEPLOY_LNPLAYLIVE_PLUGIN" = true ]; then
    cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF
    configs:
      - source: host-mappings
        target: /root/host_mappings.csv
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
    name: lnplay_bitcoindnet
EOF

    cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF
  cln-p2pnet:
    external: true
    name: lnplay-p2pnet
EOF

    cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF

  nginxnet:
    external: true
    name: lnplay_nginxnet

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


if [ "$DEPLOY_LNPLAYLIVE_PLUGIN" = true ] && [ -f "$LNPLAY_INCUS_HOSTMAPPINGS" ]; then
    cat >> "$DOCKER_COMPOSE_YML_PATH" <<EOF

configs:
  host-mappings:
    file: ${LNPLAY_INCUS_HOSTMAPPINGS}
EOF
fi

    docker stack deploy -c "$DOCKER_COMPOSE_YML_PATH" "lnplay-cln-${CLN_ID}" >> /dev/null

done
