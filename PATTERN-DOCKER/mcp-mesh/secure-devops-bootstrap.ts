import express from 'express';
import path from 'node:path';
import { mkdir, appendFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { Readable } from 'node:stream';
import { DevOpsServer } from '../../../MCPGallery/mcp-mesh-sdk/src/DevOpsServerImpl';

type JsonRpcRequest = {
  method?: string;
  params?: {
    name?: string;
    arguments?: Record<string, unknown>;
  };
  id?: string | number | null;
};

const gatewayPort = Number(process.env.MCP_DEVOPS_GATEWAY_PORT || process.env.PORT || 3003);
const internalPort = Number(process.env.MCP_DEVOPS_INTERNAL_PORT || 3004);
const auditDir = process.env.MCP_DEVOPS_AUDIT_DIR || '/workspace/audit';
const auditFile = path.join(auditDir, 'devops-audit.jsonl');
const publicUrl = process.env.MCP_DEVOPS_PUBLIC_URL || 'https://mcp.scriptorium.escrivivir.co/mcp';
const bearerToken = process.env.MCP_DEVOPS_BEARER_TOKEN || '';
const allowedScopes = new Set(
  (process.env.MCP_DEVOPS_SCOPES || 'devops:read,devops:write-definitions,devops:delete-definitions')
    .split(',')
    .map((value) => value.trim())
    .filter(Boolean),
);

const readTools = new Set([
  'list_prompts',
  'get_prompt',
  'list_resources',
  'get_resource',
  'get_server_status',
  'get_server_info',
  'open_web_console',
]);
const writeTools = new Set(['add_prompt', 'edit_prompt', 'add_resource', 'edit_resource', 'start_system']);
const deleteTools = new Set(['delete_prompt', 'delete_resource']);

function getRequiredScopes(body: JsonRpcRequest): string[] {
  switch (body?.method) {
    case 'initialize':
    case 'notifications/initialized':
    case 'tools/list':
    case 'resources/list':
    case 'resources/read':
    case 'prompts/list':
    case 'prompts/get':
      return ['devops:read'];
    case 'tools/call': {
      const toolName = body?.params?.name || '';
      if (deleteTools.has(toolName)) {
        return ['devops:delete-definitions'];
      }
      if (writeTools.has(toolName)) {
        return ['devops:write-definitions'];
      }
      if (readTools.has(toolName)) {
        return ['devops:read'];
      }
      return ['devops:read'];
    }
    default:
      return ['devops:read'];
  }
}

function shouldAuditWrite(body: JsonRpcRequest): boolean {
  if (body?.method !== 'tools/call') {
    return false;
  }
  const toolName = body?.params?.name || '';
  return writeTools.has(toolName) || deleteTools.has(toolName);
}

async function audit(event: Record<string, unknown>): Promise<void> {
  await mkdir(auditDir, { recursive: true });
  await appendFile(auditFile, `${JSON.stringify({ timestamp: new Date().toISOString(), ...event })}\n`, 'utf8');
}

function delay(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function waitForHealthy(url: string, attempts = 40, intervalMs = 250): Promise<void> {
  let lastError: unknown;

  for (let attempt = 0; attempt < attempts; attempt += 1) {
    try {
      const response = await fetch(url);
      if (response.ok) {
        return;
      }
      lastError = new Error(`Health endpoint returned ${response.status}`);
    } catch (error) {
      lastError = error;
    }

    await delay(intervalMs);
  }

  throw new Error(`Inner DevOpsServer did not become healthy at ${url}: ${String(lastError)}`);
}

async function startInnerServer(): Promise<{ effectivePort: number }> {
  process.env.MCP_SERVER_PORT = String(internalPort);
  process.env.DEVOPS_ROOM_PLUGIN_ENABLED = process.env.DEVOPS_ROOM_PLUGIN_ENABLED || 'false';
  process.env.XPLUS1_PLUGIN_DISABLED = process.env.XPLUS1_PLUGIN_DISABLED || 'true';

  const server = new DevOpsServer({ launcher: { socketUrl: process.env.SOCKET_MESH_URL || 'http://127.0.0.1:3010' } }) as any;
  const originalSetup = server.setupServerSpecifics.bind(server);

  server.setupServerSpecifics = async function patchedSetupServerSpecifics() {
    this.proserpinaBot = undefined;
    return originalSetup();
  };

  if (server.config?.port !== internalPort) {
    server.config = {
      ...server.config,
      port: internalPort,
    };
  }

  const effectivePort = typeof server.getConfig === 'function' ? server.getConfig().port : server.config?.port;
  if (effectivePort !== internalPort) {
    throw new Error(`Inner DevOpsServer port override failed: expected ${internalPort}, got ${String(effectivePort)}`);
  }

  await server.start();
  await waitForHealthy(`http://127.0.0.1:${internalPort}/health`);
  return { effectivePort };
}

async function proxyToInner(req: express.Request, res: express.Response): Promise<void> {
  const upstreamUrl = `http://127.0.0.1:${internalPort}${req.path}`;
  const headers = new Headers();

  Object.entries(req.headers).forEach(([key, value]) => {
    if (!value) return;
    if (['host', 'content-length', 'authorization'].includes(key.toLowerCase())) return;
    headers.set(key, Array.isArray(value) ? value.join(',') : value);
  });

  const hasBody = req.method !== 'GET' && req.method !== 'HEAD';
  const response = await fetch(upstreamUrl, {
    method: req.method,
    headers,
    body: hasBody ? JSON.stringify(req.body ?? {}) : undefined,
  });

  res.status(response.status);
  response.headers.forEach((value, key) => {
    if (['content-length', 'connection', 'transfer-encoding'].includes(key.toLowerCase())) return;
    res.setHeader(key, value);
  });

  if (!response.body) {
    res.end();
    return;
  }

  Readable.fromWeb(response.body as never).pipe(res);
}

async function main(): Promise<void> {
  if (!bearerToken) {
    throw new Error('MCP_DEVOPS_BEARER_TOKEN is required');
  }

  const { effectivePort } = await startInnerServer();

  const app = express();
  app.use(express.json({ limit: '5mb' }));

  app.get('/health', async (_req, res) => {
    res.json({
      status: 'healthy',
      gatewayPort,
      internalPort,
      effectiveInnerPort: effectivePort,
      publicUrl,
      auditFile,
      scopes: Array.from(allowedScopes),
      timestamp: new Date().toISOString(),
    });
  });

  app.get('/healthz', async (_req, res) => {
    res.status(200).send('ok');
  });

  app.all('/mcp', async (req, res) => {
    const authHeader = req.header('authorization') || '';
    const body = (req.body || {}) as JsonRpcRequest;
    const requiredScopes = getRequiredScopes(body);
    const presentedToken = authHeader.startsWith('Bearer ') ? authHeader.slice('Bearer '.length) : '';
    const tokenHash = presentedToken ? createHash('sha256').update(presentedToken).digest('hex') : undefined;

    if (!authHeader.startsWith('Bearer ')) {
      await audit({ action: 'auth_denied', reason: 'missing_bearer', requiredScopes, method: body.method, tool: body.params?.name });
      res.status(401).json({ error: 'Missing bearer token' });
      return;
    }

    if (presentedToken !== bearerToken) {
      await audit({ action: 'auth_denied', reason: 'invalid_bearer', requiredScopes, method: body.method, tool: body.params?.name, tokenHash });
      res.status(403).json({ error: 'Invalid bearer token' });
      return;
    }

    const missingScopes = requiredScopes.filter((scope) => !allowedScopes.has(scope));
    if (missingScopes.length) {
      await audit({ action: 'scope_denied', reason: 'scope_missing', requiredScopes, grantedScopes: Array.from(allowedScopes), method: body.method, tool: body.params?.name, tokenHash });
      res.status(403).json({ error: 'Token does not grant required scope', missingScopes });
      return;
    }

    if (shouldAuditWrite(body)) {
      await audit({
        action: 'write_attempt',
        method: body.method,
        tool: body.params?.name,
        requiredScopes,
        grantedScopes: Array.from(allowedScopes),
        arguments: body.params?.arguments || {},
        tokenHash,
      });
    }

    await proxyToInner(req, res);
  });

  app.get('/', (_req, res) => {
    res.json({
      name: 'scriptorium-vps-devops-gateway',
      endpoint: '/mcp',
      publicUrl,
      effectiveInnerPort: effectivePort,
      transport: 'streamable-http',
      auth: 'Authorization: Bearer <token>',
    });
  });

  app.listen(gatewayPort, () => {
    console.log(`✅ Secure DevOps gateway listening on :${gatewayPort}`);
    console.log(`🔐 Public MCP endpoint: ${publicUrl}`);
  });
}

main().catch((error) => {
  console.error('❌ Failed to bootstrap secure DevOps gateway', error);
  process.exit(1);
});
