ARG BASE_IMAGE

FROM $BASE_IMAGE

RUN apt update && apt-get install -y curl

#HEALTHCHECK --interval=1m --timeout=10s CMD curl -f http://localhost:18443 || exit 1