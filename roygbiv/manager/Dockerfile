ARG BASE_IMAGE

FROM $BASE_IMAGE

COPY ./docker-entrypoint.sh /entrypoint.sh
RUN chmod a+x /entrypoint.sh

ENTRYPOINT [ "/entrypoint.sh" ]
