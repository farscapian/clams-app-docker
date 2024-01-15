ARG BASE_IMAGE

FROM $BASE_IMAGE

RUN mkdir /output
VOLUME /output
RUN mkdir /app

# COPY the clams-app into the container for build.
ADD remote /app

WORKDIR /app
# build the project.
#RUN yarn build
EXPOSE 5173
ENV HOST=0.0.0.0
ENV PORT 5173

# install dependencies
RUN yarn

ENTRYPOINT [ "yarn", "dev-http", "--host", "0.0.0.0" ]
