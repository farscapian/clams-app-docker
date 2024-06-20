ARG NGINX_BASE_IMAGE
ARG BASE_IMAGE
FROM $BASE_IMAGE as build-stage

RUN mkdir /app
# COPY the clams-remote into the container for build.
ADD remote /app
WORKDIR /app

# build the project.
RUN yarn 
RUN yarn build

FROM $NGINX_BASE_IMAGE
RUN rm -rf /usr/share/nginx/html/*
COPY --from=build-stage /app/build /usr/share/nginx/html

ADD ./entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod a+x /usr/local/bin/entrypoint.sh

ENTRYPOINT [ "/usr/local/bin/entrypoint.sh" ]
