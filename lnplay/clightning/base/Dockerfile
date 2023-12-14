ARG BASE_IMAGE
FROM $BASE_IMAGE

# install lightning-cli bash completion
RUN curl -SLO https://raw.githubusercontent.com/scop/bash-completion/master/bash_completion \
  && mv bash_completion /usr/share/bash-completion/

COPY docker-entrypoint.sh /entrypoint.sh
COPY bashrc /home/clightning/.bashrc

RUN chmod a+x /entrypoint.sh

VOLUME ["/home/clightning"]

EXPOSE 9735 9835 8080 10000

ENTRYPOINT ["/entrypoint.sh"]

CMD ["lightningd"]

RUN apt update && apt install -y tor wait-for-it git jq dnsutils

COPY ./torrc /etc/tor/torrc

# add pyln-client needed for python plugin
RUN pip install pyln-client pytz

# add some scripts for python since cln has it installed.
RUN mkdir /scripts

COPY ./rpc-auth.py /scripts/rpc-auth.py

RUN chmod +x /scripts/rpc-auth.py
