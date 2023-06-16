FROM node:18
ARG GIT_REPO_URL

RUN mkdir /output
VOLUME /output
RUN mkdir /prism-app

# Clone the repository
RUN git clone $GIT_REPO_URL /prism-app

WORKDIR /prism-app

RUN git pull

EXPOSE 5173
ENV HOST=0.0.0.0
ENV PORT 5173

RUN npm i
