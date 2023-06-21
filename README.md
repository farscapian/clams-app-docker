# roygbiv-stack

```
WARNING: This software is new and should be used for testing and evaluation only!
```
## overview

This repo allows you to deploy the `roygbiv-stack` stack quickly in a [modern docker engine](https://docs.docker.com/engine/) using [docker swarm mode](`https://docs.docker.com/engine/swarm/`). The main scripts you need to know about are:

- [`./install.sh`](install.sh) - this script installs dockerd and other utilities needed to run the rest of this software.
- [`./up.sh`](./up.sh) - brings `roygbiv stack` up according to your `active_env.txt` file.
- [`./down.sh`](./down.sh) - brings your `roygbiv stack` down in a non-destructive way. You can pass `--purge` and volumes will be deleted.
- [`./reset.sh`](./reset.sh) - this is just a non-destructuve `down.sh`, then `up.sh`. Just saves a step. You can also pass `--purge` here.

You can specify your env file to customize your deployment. First create a file looking something like below in `./environments/domain.tld`. Then enter `domain.tld` in [`./active_env.txt`](./active_env.txt)

```config
DOCKER_HOST=ssh://ubuntu@domain.tld
DOMAIN_NAME=domain.tld
ENABLE_TLS=true
```

An `env` file overrides anything in [`./defaults.env`](./defaults.env). You can specify whether to deploy TLS and importantly, which domain you want to use (note this MUST be publicly resolvable in the DNS AND ports 80 and 443 are REQUIRED for certificate issuance and renewal).

Since we are using docker stacks, services are exposed on ALL IP addresses (you cannot specify a bind address). This is usually fine if you're running a dedicated VM in the cloud, but if you're self-hosting, ensure the host is on a protected DMZ.

If you don't specify an `env` file, you will get a default set of five CLN nodes running on regtest, all connnected to a single bitcoind backend. In addition, the [prism-browser-app](https://github.com/johngribbin/ROYGBIV-frontend) becomes available on port 80/443 at `https://domain.tld`. You may also deploy the [`clams-browser-app`](https://github.com/clams-tech/browser-app) at `https://clams.domain.tld` by updating your `env` file. All CLN nodes are configured to accept [websocket connections](https://lightning.readthedocs.io/lightningd-config.5.html) from remote web clients. The nginx server that gets deployed terminates all client TLS sessions and proxies websocket requests to the appropriate CLN node based on port number: `wss://${DOMAIN_NAME}:[9736+CLN_ID]`

> When `ENABLE_TLS=true` you MUST forward ports 80/tcp and 443/tcp during certificate issuance and renewal (i.e., PUBLIC->IP_ADDRESS:80/443) for everything to work.

## Developing Prisms

If you're interested in developing prisms on your local docker engine, consider setting the `DEV_PLUGIN_PATH=/home/username/cln-plugins` in your environment file. When this variable is set, the `roygbiv-stack` scripts will mount the path into the CLN containers. So, make your changes to the `prism-plugin.py` plugin (or whatever you're developing), then on your various lightning nodes, you can simply run the `reload_dev_plugins.sh` which iterates over all your CLN nodes and instructs them re-register the plugins.

## third party hosting

Lets say you want to create a server in the cloud so you can run `roygbiv-stack`. All we assume is you're running ubuntu 22.04 server. After getting SSH access the to VM you should copy the contents of ./install.sh and paste them into the remote VM (will try to automate this later). This installs dockerd in the instance. Then log out.

### DNS

When running in a public VM, you MUST use TLS (ENABLE_TLS=true). This means you need to set up DNS records for the system. The best setup is an ALIAS record which points to the DNS name provided by your hosting provider. If you want to deploy the Clams browser-app, you will need a CNAME for `clams.domain.tld`.

```
ALIAS,@,HOSTNAME_OF_REMOTE_VM_IN_CLOUD_PROVIDER
```

### SSH

You will also want to ensure that your `~/.ssh/config` file has a host defined for the remote host. An example is show below. `domain.tld.pem` is the SSH private key that enables you to SSH into the remote VM that is resolvele to `domain.tld`.

```
Host domain.tld
    User ubuntu
    IdentityFile /home/ubuntu/.ssh/domain.tld.pem
```

Ok, now run `ssh domain.tld` and ensure you can log into the VM before running any scripts (up/down/reset).

## regtest setup

The default regtest setup consists of a single bitcoind backend and five CLN nodes. After these nodes are deployed, they are funded then connected to each other over the p2p network. Then the following channels are opened, where `*` means all the initial btc is on that side of the channel, and `[n]` where n is the CLN index number.

1.  Alice\*[0]->Bob[1]
2.  Bob\*[1]->Carol[2]
3.  Bob\*[1]->Dave[3]
4.  Bob\*[1]->Erin[4]

This setup is useful for testing [lightning prisms](https://dergigi.com/2023/03/12/lightning-prisms/). After everything is stood up, you can control any deployed cln node using [clams-wallet](https://app.clams.tech). Using Clams, you can pay to BOLT12 offers from Alice to Bob, create and manage prisms on Bob, and see incoming payments splits on Carol, Dave, and Erin.

Configure the `prism-browser-app` against Bob who will create the prism and expose the BOLT12 offer that Alice can pay. All payments to the BOLT12 offer can be done in Alice's Clams app. Finally, you can use Clams wallet against Bob to see that BOLT12 invoices are being received and prism splits are subsequently being paid to downstream recipients.

## signet

When running signet, everything will get spun up as usual, but things will stop if signet wallet is inadequately funded. If the balance is insufficient, an on-chain address will be shown so you can send signet coins to it. We recommend having a bitcoin Core/QT client on your dev machine with a signet wallet with spendable funds to aid with testing/evaluation.

If you want to run signet, set BTC_CHAIN=signet in your active env file. By default this runs the public signet having a 10 minute block time. (The plan to to connect to [MutinyNet](https://blog.mutinywallet.com/mutinynet/) by default with 30 second block times.)

## Testing

All the scripts are configured such that you should only ever have to run `up.sh`, `down.sh`, and `reset.sh` from the root dir.

If you have already run `up.sh` certain things like building docker images and caching node info will already be taken care of.

Some flags you can add to `up.sh` and `reset.sh` to make testing more efficient are:

- `--no-channels` which will only NOT RUN the scripts in channel_templates
  - helpful for testing new network configurations
- `--retain-cache` to keep and cache files

Pass `--with-tests` WILL RUN run integration tests.

## TODO List

## QR codes

STATUS: NOT STARTED
DESCRIPTION: Add option for creating QR codes that contain url-encoded BASE64(NODE_URI+RUNE) information so they can be printed on a postcard and scanned by browser-apps for quiclky connecting to your node. This requires that the browser app is capable of scanning a qr code and parsing the query string parameters.
