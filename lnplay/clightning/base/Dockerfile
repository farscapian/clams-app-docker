ARG BASE_IMAGE

FROM $BASE_IMAGE

RUN apt update && apt install -y tor wait-for-it git jq dnsutils

COPY ./torrc /etc/tor/torrc

# add pyln-client needed for python plugin
RUN pip install pyln-client pytz

# add some scripts for python since cln has it installed.
RUN mkdir /scripts

COPY ./rpc-auth.py /scripts/rpc-auth.py

RUN chmod +x /scripts/rpc-auth.py
