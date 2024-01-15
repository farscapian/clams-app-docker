# LNPlay - Deploy a Private Lightning Network

```
WARNING: This software is new and should be used for testing and evaluation only!
```
## about `LNPlay`

This repo allows you to deploy `LNPlay` quickly in a [modern docker engine](https://docs.docker.com/engine/) using [docker swarm mode](`https://docs.docker.com/engine/swarm/`). `LNPlay` is a docker container application that deploys a bitcoin core daemon and one or more core lightning nodes to a docker engine (local or remote).  [Clams](https://clams.tech/) is deployed as the web-frontend for interacting with each of the CLN nodes over the websocket interface. Connection information can be embedded in QR codes for quick client onboarding. Each node is funded with `1.0000000` (regtest) bitcoin, so they can go around and open channels, learn about channel liquidity, test BOLT12 offers, etc. 

> Want to try this software but don't have the skill to host it yourself? Consider renting your own Private Lightning Network at [LNPlay.live](https://lnplay.live). For more information about this project, visit [lnplay.guide](https://www.lnplay.guide).

`LNPlay` run in `regtest`, `signet`, or `mainnet` modes. When running in `regtest`, various channel setups can be created. All lightning nodes are able to communicate with each other using a [docker overlay network](https://docs.docker.com/network/drivers/overlay/).

To get started, clone this repo and its submodules:

`git clone --recurse-submodules https://github.com/farscapian/lnplay`

> As mentioned, you can run LNPlay in any docker engine, either local or remote. Don't have docker engine installed in one of those locations? You can run the [./install.sh](./install.sh) file to get it installed. After running it, you may need to restart your computer or log out and back in to refresh your group membership.

## Environments

Environment files (contained in [./environments/](./environments)) are where you specify the parameters of your deployment. Anything you specify in your env file overrides anything in [`./defaults.env`](./defaults.env). Here's an example env file called `domain.tld` that will deploy 10 CLN nodes to a [dockerd](https://docs.docker.com/engine/reference/commandline/dockerd/) running on `domain.tld` in `signet` with TLS enabled. Check out our [AWS hosting guide](./docs/aws-hosting-guide.md) for more details on hosting your own LNPlay instance on AWS.

```config
DOCKER_HOST=ssh://ubuntu@domain.tld
BACKEND_DOMAIN_NAME=lnplay.domain.tld
FRONTEND_DOMAIN_NAME=remote.domain.tld
ENABLE_TLS=true
BTC_CHAIN=signet
CLN_COUNT=10
```

## Running the scripts

First, update `active_env.txt` to set the active environment file, then run the following scripts:

### [`./up.sh`](./up.sh)

Brings `LNPlay` up according to your active environment definition.

### [`./down.sh`](./down.sh)

Brings your `LNPlay` down in a non-destructive way.

### [`./purge.sh`](./purge.sh) 

Deletes docker volumes related to your active env so you can reset your environment. This is very useful for development. Note mainnet is NEVER deleted! But if you absolutely must, you can run `docker volume rm VOLUME_NAME`.

### [`./reset.sh`](./reset.sh) 

This is just a non-destructive `down.sh`, then `up.sh`. Just saves a step. Like `down.sh`, you can pass the `--purge` option to invoke `purge.sh`.

### [`./run_load_tests.sh`](./run_load_tests.sh)

This script allows you to perform load testing against a remote `LNPlay` deployment.

### [`./bitcoin-cli.sh`](./bitcoin-cli.sh)

Allows you to interact with the current bitcoind instance.

### [`./lightning-cli.sh`](./lightning-cli.sh)

Allows you to interact with the CLN instances. Just add the `--id=12` to access a specific core lightning node. For example: `./lightning-cli.sh --id=12 getinfo`

## BTC_CHAIN=[regtest|signet|mainnet]

### regtest

The default environment deploys everything in `regtest` mode to your local docker daemon. By default there are 5 CLN nodes all backed by a single bitcoind node having a block time of 5 seconds (override with `REGTEST_BLOCK_TIME`) (see EBT below). Each CLN node is connected to [docker overlay network](https://docs.docker.com/network/drivers/overlay/) so they're gossiping on the same P2P network. Each CLN node is funded with `100,000,000 sats`, aka `1 BTC`.

> `Effective Block Time`: In the case of LNPlay, the more CLN nodes you deploy, the longer the Effective Block Time (EBT) -- or the time which each respective CLN node "notices" a change in the block height. Each CLN node polls `bitcoind` to check the blockheight, and because `LNPLay` deploys a lot of CLN nodes, there is a need to "spread out" the polling activity evenly among the nodes so as to not overburden `bitcoind`. The Effective Block Time is UX time -- what the user experiences for the block time. It can be found in the CLN yaml output as `CLN_BITCOIND_POLL_SETTING`. By default, LNPlay targets a EBT of 5 seconds for a 200 CLN node count environment.

### signet

If you want to run signet, set `BTC_CHAIN=signet` in your env file. The scripts will stop if the bitcoind signet wallet is inadequately funded. If the balance is insufficient, an on-chain address will be shown so you can send signet coins to it. It is recommended to have a bitcoin Core/QT client on your dev machine with a signet wallet with spendable funds to aid with testing/evaluation.

### mainnet

It is not recommend to run `mainnet` at this time due to how new this software is. But it runs similarly to signet.

## Configuration Settings

The following table shows the most common configuration settings.

|Environment Variable|default value|Description|
|---|---|---|
|`BTC_CHAIN`|`regtest`|Set the chain you want to deploy: regtest, signet, mainnet.|
|`CLN_COUNT`|`5`|The total number of CLN nodes to deploy. Max is `MAX_SUPPORTED_NODES=200`|
|`BACKEND_DOMAIN_NAME`|`lnplay`|Default backend lnplay FQDN (e.g., lnplay.domain.tld|
|`FRONTEND_DOMAIN_NAME`|`remote`|Default frontend remote FQDN (e.g., remote.domain.tld)|
|`DEV_PLUGIN_PATH`|`null`|Override the local (i.e., 127.0.0.0) CLN plugin path which gets mounted into the CLN containers.|
|`ENABLE_TOR`|`false`|Deploy a TOR proxy for each CLN node so you can create lightning channels with onion-only endpoints.|
|`ENABLE_TLS`|`false`|If true, letsencrypt certificates will be generated. This requires DNS and firewall settings to be properly configured.|
|`REGTEST_BLOCK_TIME`|`5`|Adjust the blocktime (in seconds) used in regtest environments.|
|`CHANNEL_SETUP`|`none`,`prism`|By default, no channels are created. If `prism`, a layout useful for developing prisms will be established.|
|`ENABLE_BITCOIND_DEBUGGING_OUTPUT`|`false`|If true, bitcoind will emit debugging information.|
|`CLN_P2P_PORT_OVERRIDE`|`null`|If specified, this port will be used in the `--announce-addr=` on your mainnet or signet node 0.|
|`NAMES_FILE_PATH`|[./names/names.txt](./names/names.txt)|Provide a custom list of aliases for the CLN nodes. Should be a fully qualified path.|
|`COLORS_FILE_PATH`|[./names/colors.txt](./names/colors.txt)|Provide a custom list of node colors.|
|`LNPLAY_SERVER_PATH`|`$(pwd)/lnplay/stacks`|Specify where deployment articfacts are stored.|
|`DIRECT_LINK_FRONTEND_URL_OVERRIDE_FQDN`|`null`|If specified, overrides the `https://${BACKEND_DOMAIN_NAME}` to specified value: e,g., 'app.clams.tech'|
|`ENABLE_CLAMS_V2_CONNECTION_STRINGS`|`true`|If true, will emit Clams v2 Connection String format with "LARP mode".|
|`DO_NOT_DEPLOY`|`false`|Set to true to use as a safeguard against inadvertant state changes to an environment.|
|`CONNECT_NODES`|`true`|By default, all regtest nodes are connected to each other to bootstrap the p2p network.|
|`RENEW_CERTS`|`true`|Certificate renewal will be attempted.|
|`DEPLOY_CLAMS_REMOTE`|`true`|By default, Clams gets deployed to port 80/443.|

There are [other options](./defaults.env) in there that might be worth overriding, but the above list should cover most use cases.

### CHANNEL_SETUP=prism

The [`prism` channel setup](./channel_templates/create_prism_channels.sh) is useful for testing [`BOLT12 Prisms`](https://github.com/gudnuf/bolt12-prism). In set to `prism` Alice (`node0`) opens a channel to Bob (`node1`), then [Bob opens multiple channels](https://docs.corelightning.org/reference/lightning-multifundchannel) with every subsequent node after Bob. Then on Bob, a BOLT12 Prism is created. When Alice pays Bob's BOLT12 Prism Offer, Bob splits the regtest coins payment to the remaining `n` nodes.

## Connection Information

When you bring your services up, the [./show_cln_uris.sh](./show_cln_uris.sh) script will emit connection information, but also saves [direct links](https://github.com/clams-tech/App/commit/97cb83a3bd519248da3cba08dd438846cb6d212d) to `./output/cln_connection_info_${BACKEND_DOMAIN_NAME}.csv`. This file can be used as input for 1) the [load testing submodule](https://github.com/aaronbarnardsound/coreln-network-loadtest).

These QR codes can be generated by adding the `--qrcode` option to `./show_cln_uris.sh`. It is recommended to print out cards before hand, then use a label maker to print out the individual QR codes with sticker backing. Maintain the order of the connection information, if possible.

## Developing Plugins using `LNPlay`

When deploying your application to a local docker engine, the CLN plugin path will get mounted into each CLN instance (container). If you want to make updates to the ``, for example, make the change, then run `reload_dev_plugins.sh` which iterates over each CLN node and instructs it reload the prism.py the newly updated plugin.

# Presenter Tools

Global Network Graph Visualizers:

* [This repo](https://github.com/evansmj/cln-node-visualization) can be used to view a global channel graph.
