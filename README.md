# lnplay

```
WARNING: This software is new and should be used for testing and evaluation only!
```
## about `lnplay`

This repo allows you to deploy the `lnplay` quickly in a [modern docker engine](https://docs.docker.com/engine/) using [docker swarm mode](`https://docs.docker.com/engine/swarm/`). What is `lnplay`? It's Bitcoin-only BOLT12 Prism Infrastructure. `lnplay` deploys the backend bitcoind and core lightning infrastructure and also exposes Clams wallet for interacting with the various nodes. You can deploy multiple CLN nodes in various modes operation (e.g., `regtest`, `signet`, `mainnet`) in various channel setups. [Clams](https://clams.tech/) is deployed as the web-frontend for interacting with the rest of the application.

To get started, clone this repo and its submodules:

`git clone --recurse-submodules https://github.com/farscapian/lnplay`

> Don't have docker engine installed? You can run the [./install.sh](./install.sh) file to install the latest version. After running it, you may need to restart your computer or log out and back in to refresh your group membership (or use `newgrp docker`).

## Environments

Each environment file (contained in [./environments/](./environments)) is where you specify the parameters of your deployment. Anything you specify in your env file overrides anything in [`./defaults.env`](./defaults.env). Here's an example env file called `llarp.fun` that will deploy 5 CLN nodes to a [dockerd](https://docs.docker.com/engine/reference/commandline/dockerd/) running on `40.25.56.35` in `signet` with TLS enabled.

```config
DOCKER_HOST=ssh://ubuntu@40.25.56.35
DOMAIN_NAME=llarp.fun
ENABLE_TLS=true
BTC_CHAIN=signet
```
## Running the scripts

First, update `active_env.txt` to set the active environment file, then run the following scripts:

### [`./up.sh`](./up.sh)

Brings `lnplay` up according to your active environment definition.

### [`./down.sh`](./down.sh)

Brings your `lnplay` down in a non-destructive way.

### [`./purge.sh`](./purge.sh) 

Deletes docker volumes related to your active env so you can reset your environment. This is very useful for development. Note mainnet is NEVER deleted! But if you absolutely must, you can run `docker volume rm VOLUME_NAME` .

### [`./reset.sh`](./reset.sh) 

This is just a non-destructuve `down.sh`, then `up.sh`. Just saves a step. Like `down.sh`, you can pass the `--purge` option to invoke `purge.sh`.

### [`./run_load_tests.sh`](./run_load_tests.sh)

This script allows you to perform load testing against a remote `lnplay` deployment.
### [`./bitcoin-cli.sh`](./bitcoin-cli.sh)

Allows you to interact with the current bitcoind instance.

### [`./lightning-cli.sh`](./lightning-cli.sh)

Allows you to interact with the CLN instances. Just add the `--id=12` to access a specific core lightning node. For example: `./lightning-cli.sh --id=12 getinfo`

## Public Deployments

If you want to deploy public instances of `lnplay`, there are a few things to consider.

### Public DNS (ENABLE_TLS=true)

Configure an `A` record that points to the public IP address of your server. If self-hosting, set the internal DNS server resolve to the internal IP address of the host.

### Firewall

Your perimeter firewall should forward ports 80 and 443 to the host running dockerd.

### SSH

On your management machine, You will also want to ensure that your `~/.ssh/config` file has a host defined for the remote host. An example is show below. `llarp.fun.pem` is the SSH private key that enables you to SSH into the remote VM that resolves to you domain, e.g., `llarp.fun`.

```
Host llarp.fun
    HostName 40.25.56.35
    User ubuntu
    IdentityFile /home/ubuntu/.ssh/llarp.fun.pem
```
## BTC_CHAIN=[regtest|signet|mainnet]
### regtest

The default environment deploys everything in `regtest` mode to you local docker daemon. By default there are 5 CLN nodes all backed by a single bitcoind node having a block time of 5 seconds. Each CLN node is connected to each other so they're gossiping on the same P2P network. No channels are created, but each CLN node is funded with `100,000,000 sats`.

### signet

If you want to run signet, set `BTC_CHAIN=signet` in your env file. The scripts will stop if signet wallet is inadequately funded (TODO allow user to specify wallet descriptor). If the balance is insufficient, an on-chain address will be shown so you can send signet coins to it. It is recommended to have a bitcoin Core/QT client on your dev machine with a signet wallet with spendable funds to aid with testing/evaluation.

By default this runs the public signet having a 10 minute block time. Over time we may add [MutinyNet](https://blog.mutinywallet.com/mutinynet/) or other popular signets, as well as deploy private signets (which is like a private regtest, but enables scale-out for larger internet-scale llarps.

### mainnet

It is not recommend to run `mainnet`` at this time due to how new this software is. But it runs similarly to signet.

## Configuration Settings

The following table shows the most common configuration settings.

|Environment Variable|default value|Description|
|---|---|---|
|`BTC_CHAIN`|`regtest`|Set the chain you want to deploy: regtest, signet, mainnet.|
|`CLN_COUNT`|`5`|The total number of CLN nodes to deploy.|
|`ENABLE_TOR`|`false`|Deploy a TOR proxy for each CLN node so you can create lightning channels with onion-only endpoints.|
|`ENABLE_TLS`|`false`|If true, letsencrypt certificates will be generated. This requires DNS and firewall settings to be properly configured.|
|`REGTEST_BLOCK_TIME`|`5`|Adjust the blocktime (in seconds) used in regtest environments.|
|`CHANNEL_SETUP`|`none`|By default, no channels are created. If `prism`, a prism layout will be established.|
|`ENABLE_CLN_DEBUGGING_OUTPUT`|`false`|If true, bitcoind and lightningd will emit debugging information.|
|`CLN_P2P_PORT_OVERRIDE`|`null`|If specified, this port will be used in the `--announce-addr=` on your mainnet or signet node 0.|
|`NAMES_FILE_PATH`|[./names.txt](./names.txt)|Provide a custom list of aliases for the CLN nodes. Should be a fully qualified path.|
|`CLAMS_SERVER_PATH`|`$(pwd)/lnplay/stacks`|Specify where deployment articfacts are stored.|
|`DIRECT_LINK_FRONTEND_URL_OVERRIDE_FQDN`|`null`|If specified, overrides the `https://${DOMAIN_NAME}` to specified value: e,g., 'app.clams.tech'|

There are [other options](./defaults.env) in there that might be worth overriding, but the above list should cover most use cases.

### CHANNEL_SETUP=prism

The [`prism` channel setup](./channel_templates/create_prism_channels.sh) is useful for testing `n-member prisms`, where `n` is the number of split recipients in the prism. Here's the basic setup: Alice (`cln-0`) opens a channel to Bob (`cln-1`), then [Bob opens multiple channels](https://docs.corelightning.org/reference/lightning-multifundchannel) with every subsequent node after Bob. This allows Alice to pay Bob's BOLT12 Prism Offer, and Bob can split the payment to the remaining `n` nodes (to do a 50-member split, set `CLN_COUNT=52`).

1.  Alice\*[0]->Bob[1]
2.  Bob\*[1]->Carol[2]
3.  Bob\*[1]->Dave[3]
4.  Bob\*[1]->...
5.  Bob\*[1]->Finney[n+2]

This setup is useful for testing and developing [BOLT12 Prisms](https://www.roygbiv.guide). After the channels are created you can control any deployed cln node using [clams-wallet](https://clams.tech). With Clams, you can pay to `BOLT12 Prism Offers` from Alice to Bob. From Bob you can create and manage prisms and view incoming payments and outgoing payment splits. Finally on Carol, Dave, and Erin, you can see incoming payments as a result of prism payouts on Bob. For more information, [take a look at the ROYGBIV demo environment](https://www.roygbiv.guide/demo)

## Connection Information

When you bring your services up, the [./show_cln_uris.sh](./show_cln_uris.sh) script will emit connection information, but also saves [direct links](https://github.com/clams-tech/App/commit/97cb83a3bd519248da3cba08dd438846cb6d212d) to `./output/cln_connection_info_${DOMAIN_NAME}.csv`. This file can be used as input for 1) the [load testing submodule](https://github.com/aaronbarnardsound/coreln-network-loadtest) or 2) the [clams-qr-generator](https://github.com/clams-tech/clams-qr-generator). These QR codes can be printed out and given to individuals so they can connect to the respective core lightning node. All connectivity between a browser and the back-end core lightning services use the [`--experimental-websocket-port`](https://docs.corelightning.org/reference/lightningd-config#experimental-options) functionality in core lightning.

## Developing Plugins using `lnplay`

When deploying your application to a local docker engine, the CLN plugin path will get mounted into each CLN instance (container). If you want to make updates to the `prism-plugin.py`, for example, make the change, then run `reload_dev_plugins.sh` which iterates over each CLN node and instructs it reload the newly updated plugin.
