FROM polarlightning/clightning:23.02.2

RUN apt update && apt install -y tor

COPY ./torrc /etc/tor/torrc

# add pyln-client needed for python plugin
RUN pip install pyln-client

# copy the plugins directory down
COPY ./cln-plugins/ /plugins/

RUN chmod +x /plugins/*.py

VOLUME /opt/c-lightning-rest