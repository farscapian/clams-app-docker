ARG BASE_IMAGE
FROM $BASE_IMAGE
ENV DEBIAN_FRONTEND=noninteractive
RUN apt update && apt install -y curl wait-for-it tini

# Override the ENTRYPOINT
ENTRYPOINT ["/usr/bin/tini", "--"]

# this is used for bitcoin-cli so it can load the .cookie file
COPY bitcoin-cli-entrypoint.sh /bitcoin-cli
RUN chmod +x /bitcoin-cli

CMD ["bitcoind"]