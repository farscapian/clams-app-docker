#!/bin/bash

set -exu
cd "$(dirname "$0")"

cat > "$CLN_DOCKERFILE_PATH" <<EOF
ARG BASE_IMAGE
FROM \$BASE_IMAGE
VOLUME /opt/c-lightning-rest
ENV DEBIAN_FRONTEND=noninteractive
EOF


if [ "$DOMAIN_NAME" = "127.0.0.1" ]; then
    cat >> "$CLN_DOCKERFILE_PATH" <<EOF
# we can mount into the this path when we're working locally.
RUN mkdir /cln-plugins
VOLUME /cln-plugins
EOF
fi

if [ "$DEPLOY_LNPLAYLIVE_PLUGIN" = true ]; then
    cat >> "$CLN_DOCKERFILE_PATH" <<EOF
# get sovereign stack from remote git repo
RUN mkdir /sovereign-stack
VOLUME /sovereign-stack
EOF
fi

# if we're deploying to a remote dockerd, we source sovereign stack from git repos.
if [ "$DEPLOY_LNPLAYLIVE_PLUGIN" = true ] && [ "$DOMAIN_NAME" != "127.0.0.1" ]; then
    cat >> "$CLN_DOCKERFILE_PATH" <<EOF
RUN git clone --branch tabconf --recurse-submodules https://git.sovereign-stack.org/ss/sovereign-stack.git /sovereign-stack
EOF
fi

cat >> "$CLN_DOCKERFILE_PATH" <<EOF
# install basic software.
RUN apt update
RUN apt install -y wait-for-it sshfs wget
EOF

# if we're deploying lnplaylive, install the dependencies.
if [ "$DEPLOY_LNPLAYLIVE_PLUGIN" = true ]; then
    cat >> "$CLN_DOCKERFILE_PATH" <<EOF
# copy the deprovisioning script to the image.
COPY ./lnplaylive_deprovision.sh /root/deprovision.sh
RUN chmod +x /root/deprovision.sh

RUN wget -O /usr/bin/lxc https://github.com/canonical/lxd/releases/download/lxd-5.18/bin.linux.lxc
RUN chmod +x /usr/bin/lxc

# # install docker client
# Add Docker's official GPG key:
RUN apt-get update
RUN apt-get install -y ca-certificates curl gnupg
RUN install -m 0755 -d /etc/apt/keyrings
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
RUN chmod a+r /etc/apt/keyrings/docker.gpg

# Add the repository to Apt sources:
RUN echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian bullseye stable" | tee /etc/apt/sources.list.d/docker.list
RUN apt-get update
RUN apt-get install -y docker-ce-cli cron procps bc gridsite-clients openssh-client rsync

EOF

    # add the lnplay live plugins.
    if [ "$DOMAIN_NAME" != "127.0.0.1" ]; then 
        cat >> "$CLN_DOCKERFILE_PATH" <<EOF
# provisioning plugin
ADD ./cln-plugins/lnplaylive/invoice_paid.py /plugins/lnplaylive/invoice_paid.py
RUN chmod +x /plugins/lnplaylive/invoice_paid.py

ADD ./cln-plugins/lnplaylive/lnplay-live-api.py /plugins/lnplaylive/lnplay-live-api.py
RUN chmod +x /plugins/lnplaylive/lnplay-live-api.py

ADD ./cln-plugins/lnplaylive/lnplaylive.sh /plugins/lnplaylive/lnplaylive.sh
RUN chmod +x /plugins/lnplaylive/lnplaylive.sh

ADD ./cln-plugins/lnplaylive/lxc_client_init.sh /plugins/lnplaylive/lxc_client_init.sh
RUN chmod +x /plugins/lnplaylive/lxc_client_init.sh

ADD ./cln-plugins/lnplaylive/provision.sh /plugins/lnplaylive/provision.sh
RUN chmod +x /plugins/lnplaylive/provision.sh

ADD ./cln-plugins/lnplaylive/stub_confs.sh /plugins/lnplaylive/stub_confs.sh
RUN chmod +x /plugins/lnplaylive/stub_confs.sh

EOF
    fi
fi

if [ "$DEPLOY_PRISM_PLUGIN" = true ]; then
    cat >> "$CLN_DOCKERFILE_PATH" <<EOF
# let's embed the plugins into the image.
ADD ./cln-plugins/bolt12-prism/prism-plugin.py /plugins/bolt12-prism/prism-plugin.py
RUN chmod +x /plugins/bolt12-prism/prism-plugin.py
EOF
fi

cat >> "$CLN_DOCKERFILE_PATH" <<EOF
# add entrypoint.sh
COPY ./entrypoint.sh /entrypoint.sh
RUN chmod a+x /entrypoint.sh
ENV SLEEP=0
ENTRYPOINT [ "/entrypoint.sh" ]
EOF