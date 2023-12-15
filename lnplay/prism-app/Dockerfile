ARG BASE_IMAGE
FROM $BASE_IMAGE
RUN mkdir /output
VOLUME /output
RUN mkdir /prism-app
COPY ROYGBIV-frontend/ /prism-app
WORKDIR /prism-app
EXPOSE 5173
ENV HOST=0.0.0.0
ENV PORT 5173
RUN npm i