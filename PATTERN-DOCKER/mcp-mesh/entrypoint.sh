#!/usr/bin/env sh
set -eu

: "${MCP_DEVOPS_DATA_MOUNT:=/workspace/devops-data}"
: "${MCP_DEVOPS_AUDIT_DIR:=/workspace/audit}"
TARGET_DATA_DIR="/opt/aleph/ARCHIVO/PLUGINS/MCP_DATA/devops-mcp-server"

mkdir -p "$MCP_DEVOPS_DATA_MOUNT" "$MCP_DEVOPS_AUDIT_DIR" "$(dirname "$TARGET_DATA_DIR")"
ln -sfn "$MCP_DEVOPS_DATA_MOUNT" "$TARGET_DATA_DIR"

cd /opt/aleph/MCPGallery/mcp-mesh-sdk
exec npx tsx /opt/aleph/ScriptoriumVps/PATTERN-DOCKER/mcp-mesh/secure-devops-bootstrap.ts
