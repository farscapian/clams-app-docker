ARG BASE_IMAGE
FROM $BASE_IMAGE

RUN apt update && apt install -y tor

COPY ./torrc /etc/tor/torrc

ENTRYPOINT [ "tor", "-f", "/etc/tor/torrc" ]
