ARG BASE_IMAGE

FROM $BASE_IMAGE

# copy the plugins directory down
COPY ./cln-plugins/bolt12-prism /plugins/

RUN chmod +x /plugins/*.py

VOLUME /opt/c-lightning-rest

RUN mkdir /dev-plugins

VOLUME /dev-plugins

COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

ENTRYPOINT [ "/usr/bin/tini", "--", "/entrypoint.sh" ]