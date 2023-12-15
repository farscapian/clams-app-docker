# AWS Self Hosting Guide

Want to run your own LNPlay on an AWS instance? This is what you will want to do.

# Prerequisites

You need to have an AWS account. All you will be doing is deploying an EC2 instance to an AWS data center. Try to choose a region that is geographically closest to the attendees. You will also need a domain name and the ability to create DNS A records.

You development machine MUST be able to SSH into remote VMs you create in the cloud. This works best on Ubuntu, but anyone with SSH knowledge should be able to do it on Windows as well. *Note there may be a need to use SCP as well.

## Public Deployments

If you want to deploy public instances of `LNPlay`, there are a few things to consider.

### Firewall

Your perimeter firewall should forward ports 80 and 443 to the host running dockerd.

### Public DNS (ENABLE_TLS=true)

Configure an `A` record that points to the public IP address of your server. If self-hosting, set the internal DNS server resolve to the internal IP address of the host.

### SSH

On your management machine, You will also want to ensure that your `~/.ssh/config` file has a host defined for the remote host. An example is show below. `domain.tld.pem` is the SSH private key that enables you to SSH into the remote VM that resolves to you domain, e.g., `domain.tld`.

```
Host domain.tld
    HostName domain.tld
    User ubuntu
    IdentityFile /home/ubuntu/.ssh/domain.tld.pem
```