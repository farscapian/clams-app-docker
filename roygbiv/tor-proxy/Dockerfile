FROM ubuntu:latest

RUN apt update && apt install -y tor

COPY ./torrc /etc/tor/torrc

ENTRYPOINT [ "tor", "-f", "/etc/tor/torrc" ]