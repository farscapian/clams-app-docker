FROM node:18
RUN mkdir /lnplaylive
COPY app/ /lnplaylive
WORKDIR /lnplaylive
EXPOSE 5173
ENV HOST=0.0.0.0
ENV PORT 5173
RUN npm i
RUN npm run build
