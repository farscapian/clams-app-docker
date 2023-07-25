ARG BASE_IMAGE

FROM $BASE_IMAGE

RUN mkdir /output
VOLUME /output
RUN mkdir /app

# Clone the repository
ADD app /app

WORKDIR /app

# install dependencies
RUN yarn

# build the project.
RUN yarn build

# This command copies everything from 
ENTRYPOINT [ "cp", "-a", "/app/build/.", "/output/" ]
