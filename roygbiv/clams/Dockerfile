FROM node:19.7

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
