ARG BASE_IMAGE

FROM $BASE_IMAGE

ARG DEBIAN_FRONTEND=noninteractive
RUN apt update && apt install -y wait-for-it

COPY ./docker-entrypoint.sh /entrypoint.sh
RUN chmod a+x /entrypoint.sh

ENTRYPOINT [ "/entrypoint.sh" ]
