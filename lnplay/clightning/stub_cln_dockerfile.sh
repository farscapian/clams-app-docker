#!/bin/bash

set -eu
cd "$(dirname "$0")"

cat > "$CLN_DOCKERFILE_PATH" <<EOF
ARG BASE_IMAGE
FROM \$BASE_IMAGE
ENV DEBIAN_FRONTEND=noninteractive
ENV CLN_ALIAS=
ENV CLN_COLOR=
ENV BITCOIND_RPC_USERNAME=
ENV BITCOIND_RPC_PASSWORD=
ENV CLN_NAME=
ENV ENABLE_TOR=false
ENV ENABLE_CLN_REST=true
ENV BACKEND_FQDN=
ENV PLUGIN_PATH=
ENV DEPLOY_CLBOSS_PLUGIN=false
ENV DEPLOY_PRISM_PLUGIN=true
ENV DEPLOY_RECKLESS_WRAPPER_PLUGIN=true
ENV DEPLOY_LNPLAYLIVE_PLUGIN=
ENV CLN_BITCOIND_POLL_SETTING=1
EOF


if [ "$BACKEND_FQDN" = "127.0.0.1" ]; then
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
if [ "$DEPLOY_LNPLAYLIVE_PLUGIN" = true ]; then
    cat >> "$CLN_DOCKERFILE_PATH" <<EOF
RUN git clone --branch incus --recurse-submodules https://git.sovereign-stack.org/ss/sovereign-stack.git /sovereign-stack
EOF
fi

cat >> "$CLN_DOCKERFILE_PATH" <<EOF
# install basic software.
RUN apt update
RUN apt install -y wait-for-it sshfs wget dnsutils 
#RUN apt install -y systemctl 
#RUN apt install -y systemd
EOF

# if we're deploying lnplaylive, install the dependencies.
if [ "$DEPLOY_LNPLAYLIVE_PLUGIN" = true ]; then
    cat >> "$CLN_DOCKERFILE_PATH" <<EOF

# copy the incus client binary into the image
COPY ./bin.linux.incus.x86_64 /usr/bin/incus
RUN chmod +x /usr/bin/incus

# # install docker client
# TODO CONVERT THIS DOCKER INSTALL to install.sh from LNPLay.
# Add Docker's official GPG key:
RUN apt update

RUN apt install -y ca-certificates curl gnupg
RUN install -m 0755 -d /etc/apt/keyrings
RUN curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
RUN chmod a+r /etc/apt/keyrings/docker.gpg

# Add the repository to Apt sources:
RUN echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian bullseye stable" | tee /etc/apt/sources.list.d/docker.list
RUN apt update
RUN apt install -y docker-ce-cli cron procps bc gridsite-clients openssh-client rsync

EOF

    # add the lnplay live plugins/scripts
    # TODO this can be simplified probably; no need to specify every py sh
    if [ -n "$DOCKER_HOST" ]; then 
        cat >> "$CLN_DOCKERFILE_PATH" <<EOF
# provisioning plugin
ADD ./cln-plugins/lnplaylive/invoice_paid.py /plugins/lnplaylive/invoice_paid.py
RUN chmod +x /plugins/lnplaylive/invoice_paid.py

ADD ./cln-plugins/lnplaylive/lnplay-live-api.py /plugins/lnplaylive/lnplay-live-api.py
RUN chmod +x /plugins/lnplaylive/lnplay-live-api.py

ADD ./cln-plugins/lnplaylive/lnplaylive.sh /plugins/lnplaylive/lnplaylive.sh
RUN chmod +x /plugins/lnplaylive/lnplaylive.sh

ADD ./cln-plugins/lnplaylive/incus_client_init.sh /plugins/lnplaylive/incus_client_init.sh
RUN chmod +x /plugins/lnplaylive/incus_client_init.sh

ADD ./cln-plugins/lnplaylive/provision.sh /plugins/lnplaylive/provision.sh
RUN chmod +x /plugins/lnplaylive/provision.sh

ADD ./cln-plugins/lnplaylive/stub_confs.sh /plugins/lnplaylive/stub_confs.sh
RUN chmod +x /plugins/lnplaylive/stub_confs.sh

EOF
    fi
fi

if [ "$DEPLOY_PRISM_PLUGIN" = true ] && [ -n "$DOCKER_HOST" ]; then
    cat >> "$CLN_DOCKERFILE_PATH" <<EOF
# let's embed the plugins into the image.
ADD ./cln-plugins/bolt12-prism/lib.py /plugins/bolt12-prism/lib.py
ADD ./cln-plugins/bolt12-prism/bolt12-prism.py /plugins/bolt12-prism/bolt12-prism.py
RUN chmod +x /plugins/bolt12-prism/bolt12-prism.py /plugins/bolt12-prism/lib.py
EOF

fi

if [ "$DEPLOY_RECKLESS_WRAPPER_PLUGIN" = true ] && [ -n "$DOCKER_HOST" ]; then
    cat >> "$CLN_DOCKERFILE_PATH" <<EOF
# let's embed the plugins into the image.
ADD ./cln-plugins/cln-reckless-wrapper/cln-reckless-wrapper.py /plugins/cln-reckless-wrapper/cln-reckless-wrapper.py
RUN chmod +x /plugins/cln-reckless-wrapper/cln-reckless-wrapper.py
EOF

fi


if [ "$DEPLOY_CLBOSS_PLUGIN" = true ] && [ -n "$DOCKER_HOST" ]; then
    cat >> "$CLN_DOCKERFILE_PATH" <<EOF
# copy the CLBOSS binary to the plugin path.
ADD ./cln-plugins/clboss/clboss /plugins/clboss/clboss
RUN chmod +x /plugins/clboss/clboss
RUN apt install -y libev-dev
EOF

fi

cat >> "$CLN_DOCKERFILE_PATH" <<EOF
# add entrypoint.sh
COPY ./entrypoint.sh /entrypoint.sh
RUN chmod a+x /entrypoint.sh
ENV SLEEP=0
ENTRYPOINT [ "/entrypoint.sh" ]
EOF