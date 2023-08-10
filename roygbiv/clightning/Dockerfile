ARG BASE_IMAGE

FROM $BASE_IMAGE

RUN apt update && apt install -y tor

COPY ./torrc /etc/tor/torrc

# add pyln-client needed for python plugin
RUN pip install pyln-client

# copy the plugins directory down
COPY ./cln-plugins/bolt12-prism /plugins/

RUN chmod +x /plugins/*.py

VOLUME /opt/c-lightning-rest

RUN mkdir /dev-plugins

VOLUME /dev-plugins



# add some scripts for python since cln has it installed.
RUN mkdir /scripts

COPY ./rpc-auth.py /scripts/rpc-auth.py

RUN chmod +x /scripts/rpc-auth.py