FROM node:0.10

ADD . /app

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    graphicsmagick \
    html2ps \
 && npm install coffee-script -g

ENV PORT 3000
ENV USE_LOCAL_DISK_PATH /data

VOLUME /data

WORKDIR /app

ENV NODE_ENV production

RUN npm install \
 && npm cache clear

CMD ["coffee", "app.coffee"]
