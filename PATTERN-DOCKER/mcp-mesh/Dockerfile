FROM node:22-alpine

RUN apk add --no-cache bash git python3 make g++

WORKDIR /opt/aleph

COPY MCPGallery /opt/aleph/MCPGallery
COPY ScriptoriumVps /opt/aleph/ScriptoriumVps

WORKDIR /opt/aleph/MCPGallery/mcp-mesh-sdk
RUN npm install --include=dev --no-fund --no-audit

RUN chmod +x /opt/aleph/ScriptoriumVps/PATTERN-DOCKER/mcp-mesh/entrypoint.sh \
    && mkdir -p /workspace/devops-data /workspace/audit /opt/aleph/ARCHIVO/PLUGINS/MCP_DATA

ENV NODE_ENV=production \
    MCP_DEVOPS_GATEWAY_PORT=3003 \
    MCP_DEVOPS_INTERNAL_PORT=3004 \
    MCP_DEVOPS_DATA_MOUNT=/workspace/devops-data \
    MCP_DEVOPS_AUDIT_DIR=/workspace/audit \
    DEVOPS_ROOM_PLUGIN_ENABLED=false \
    XPLUS1_PLUGIN_DISABLED=true

ENTRYPOINT ["/opt/aleph/ScriptoriumVps/PATTERN-DOCKER/mcp-mesh/entrypoint.sh"]
