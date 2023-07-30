# roygbiv-stack

```
WARNING: This software is new and should be used for testing and evaluation only!
```
## About ROYGBIV-stack

This repo allows you to deploy the `roygbiv-stack` quickly in a [modern docker engine](https://docs.docker.com/engine/) using [docker swarm mode](`https://docs.docker.com/engine/swarm/`). What is ROYGBIV-stack? It's Bitcoin-only BOLT12 Prism Infrastructure. `roygbiv-stack` deploys the backend bitcoind and core lightning infrastructure and also exposes Clams wallet for interactving with your various nodes. You can deploy multiple CLN nodes in various modes operation (e.g., regtest, signet, mainnet), various channel setups, all integrated with Clams wallet.

To get started, clone this repo to your linux host with `git clone --recurse-submodules https://github.com/farscapian/roygbiv-stack`

`Don't have docker engine installed? You can run the ./install.sh file to install the latest version of docker. After running it, you may need to restart your computer or refresh group membership.`

The remaining scripts all depend on your active environment.

## Environments

Each environment file (contained in ./environments/) is where you specify the parameters of your deployment. Anything you specify in your env file overrides anything in [`./defaults.env`](./defaults.env). Here's an example env file called `llarp.fun` that will deploy 5 CLN nodes to a VM at `40.25.56.35` running `signet` with TLS enabled.

```config
DOCKER_HOST=ssh://ubuntu@40.25.56.35
DOMAIN_NAME=llarp.fun
ENABLE_TLS=true
BTC_CHAIN=signet
```
## User Interface

### [`./up.sh`](./up.sh)

Brings `roygbiv-stack` up according to your active environment definition.

### [`./down.sh`](./down.sh)

Brings your `roygbiv-stack` down in a non-destructive way.

### [`./purge.sh`](./purge.sh) 

Deletes docker volumes related to your active env so you can reset your environment. This is very useful for development. Note mainnet is NEVER deleted! But if you absolutely must, you can run `docker volume rm VOLUME_NAME` .

### [`./reset.sh`](./reset.sh) 

This is just a non-destructuve `down.sh`, then `up.sh`. Just saves a step. Like `down.sh`, you can pass the `--purge` option to invoke `purge.sh`.

## Public Deployments

If you want to deploy public instances of `roygbiv-stack`, there are a few things to consider.

### Public DNS (ENABLE_TLS=true)

Configure an `A` record that points to the public IP address of your server. If self-hosting, set configure the the internal DNS server resolve to the internal IP address of the host.

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

The default environment `local.env` deploys everything in `regtest` mode to you local docker daemon. By default there are 5 CLN nodes all backed by a single bitcoind node having a block time of 5 seconds. Each CLN node is connected to each other so they're gossiping on the same P2P network. No channels are created, but each CLN node is funded with `100,000,000 sats`.

### signet

If you want to run signet, set `BTC_CHAIN=signet` in your env file. The scripts will stop if signet wallet is inadequately funded (TODO allow user to specify wallet descriptor). If the balance is insufficient, an on-chain address will be shown so you can send signet coins to it. We recommend having a bitcoin Core/QT client on your dev machine with a signet wallet with spendable funds to aid with testing/evaluation.

By default this runs the public signet having a 10 minute block time. Over time we may add [MutinyNet](https://blog.mutinywallet.com/mutinynet/) or other popular signets, as well as deploy private signets (which is like a private regtest, but enables scale-out for larger internet-scale llarps.

### mainnet

We do not recommend running mainnet at this time due to how new this software is. But it runs similarly to signet.
## Configuration Settings

The following table shows the most common

|Environment Variable|default value|Description|
|---|---|---|
|`BTC_CHAIN`|`regtest`|Set the chain you want to deploy: regtest, signet, mainnet.|
|`CLN_COUNT`|`5`|The total number of CLN nodes to deploy.|
|`ENABLE_TOR`|`false`|Deploy a TOR proxy for each CLN node so you can create lightning channels with onion-only endpoints.|
|`ENABLE_TLS`|`false`|If true, letsencrypt certificates will be generated. This requires DNS and firewall settings to be properly configured.|
|`REGTEST_BLOCK_TIME`|`5`|Adjust the blocktime (in seconds) used in regtest environments.|
|`CHANNEL_SETUP`|`none`|By default, no channels are created. If `prism`, a prism layout will be established.|
|`ENABLE_DEBUGGING_OUTPUT`|`false`|If true, bitcoind and lightningd will emit debugging information.|
|`CLN_P2P_PORT_OVERRIDE`|`null`|If specified, this port will be used in the `--announce-addr=` on your mainnet node 0.|

There are other options in there that might be worth overriding, but the above list should cover most use cases.

## CHANNEL_SETUP=prism

The `prism` channel setup is useful for testing `n-member prisms`, where `n` is the number of split recipients in the prism. Here's the basic setup: Alice opens a channel to Bob, then [Bob opens multiple channels](https://docs.corelightning.org/reference/lightning-multifundchannel) with every subsequent node after Bob. This allows Alice to pay Bob's BOLT12 Prism Offer, and Bob can split the payment to the remaining `n` nodes (to do a 50-member split, set `CLN_COUNT=52`).

1.  Alice\*[0]->Bob[1]
2.  Bob\*[1]->Carol[2]
3.  Bob\*[1]->Dave[3]
4.  Bob\*[1]->...
5.  Bob\*[1]->Finney[n+2]

This setup is useful for testing and developing [BOLT12 Prisms](https://www.roygbiv.guide). After the channels are created you can control any deployed cln node using [clams-wallet](https://clams.tech). With Clams, you can pay to `BOLT12 Prism Offers` from Alice to Bob. From Bob you can create and manage prisms and view incoming payments and outgoing payment splits. Finally on Carol, Dave, and Erin, you can see incoming payments as a result of prism payouts on Bob. For more information, [take a look at the ROYGBIV demo environment](https://www.roygbiv.guide/demo)

## Connection Information

When you bring your services up, the [./show_cln_uris.sh](./show_cln_uris.sh) script will emit connection information, but also saves [direct links](https://github.com/clams-tech/App/commit/97cb83a3bd519248da3cba08dd438846cb6d212d) to `./output/cln_connection_info_${DOMAIN_NAME}.csv`. This file can be used as input for 1) the [load testing repo](https://github.com/aaronbarnardsound/coreln-network-loadtest) or 2) the [clams-qr-generator](https://github.com/clams-tech/clams-qr-generator). These QR codes can be printed out and given to individuals so they can connect to the respective core lightning node. All connectivity between a browser and the back-end core lightning services use the `--experimental-websocket-port` functionality in core lightning.

## Testing

All the scripts are configured such that you should only ever have to run `up.sh`, `down.sh`, and `reset.sh` from the root dir.

Some flags you can add to `up.sh` and `reset.sh` to make testing more efficient are:

- `--no-channels` which will only NOT RUN the scripts in channel_templates
  - helpful for testing new network configurations
- `--retain-cache` to keep and cache files
- `--no-tests` will NOT run integration tests.
- `--purge` (reset.sh) - deletes regtest/signet on disk.

## Developing Plugins using ROYGBIV-stack

When deploying your application to a local docker engine, the CLN plugin path will get mounted into echo CLN container. If you want to make updates to the `prism-plugin.py`, for example, you can make change, then just run `reload_dev_plugins.sh` which iterates over each CLN node and instructs it reload the newly updated prism plugin.

If you want, you can set `DEV_PLUGIN_PATH=/home/username/cln-plugins` in your environment file. When this variable is set, the `roygbiv-stack` scripts will mount the path into the CLN containers. Again, just run `reload_dev_plugins.sh` and your deployed CLN nodes will get refreshed.
