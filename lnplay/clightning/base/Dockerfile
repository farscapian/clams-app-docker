ARG BASE_IMAGE
FROM $BASE_IMAGE

RUN apt update
RUN apt install curl wait-for-it git -y

# install lightning-cli bash completion
RUN curl -SLO https://raw.githubusercontent.com/scop/bash-completion/master/bash_completion \
  && mv bash_completion /usr/share/bash-completion/

# these next lines are JUST for if you're using the reckless plugin
# DEPLOY_RECKLESS_WRAPPER_PLUGIN=true

RUN apt install -y python3-venv
RUN mkdir -p /reckless-plugins
#RUN git clone --recurse-submodules https://github.com/lightningd/plugins /reckless-plugins
#RUN git clone --recurse-submodules https://github.com/jrman28/cln-htmx-getinfo /reckless-plugins/cln-htmx-getinfo
COPY ./.sources /reckless-plugins/.sources
COPY ./regtest-reckless.conf /reckless-plugins/regtest-reckless.conf

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
