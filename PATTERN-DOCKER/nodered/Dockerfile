ARG NODERED_BASE_IMAGE=nodered/node-red:latest
FROM ${NODERED_BASE_IMAGE}

USER root

RUN apk add --no-cache bash git python3 make g++

COPY ScriptoriumVps/PATTERN-DOCKER/nodered/build-local-contribs.mjs /opt/aleph/node-red/build-local-contribs.mjs
COPY ScriptoriumVps/PATTERN-DOCKER/nodered/install-contribs.mjs /opt/aleph/node-red/install-contribs.mjs
COPY ScriptoriumVps/PATTERN-DOCKER/nodered/node-red-contribs.json /opt/aleph/node-red/node-red-contribs.json
COPY ScriptoriumVps/PATTERN-DOCKER/nodered/settings.js /data/settings.js

RUN mkdir -p /data/projects /opt/aleph/node-red \
    && chown -R node-red:node-red /data /opt/aleph

USER node-red

RUN npm config set fund false \
    && npm config set audit false
