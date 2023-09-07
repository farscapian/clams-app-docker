FROM node:18
RUN mkdir /app
COPY app/ /app
WORKDIR /app
EXPOSE 5173
ENV HOST=0.0.0.0
ENV PORT 5173
RUN npm i
RUN npm run build
