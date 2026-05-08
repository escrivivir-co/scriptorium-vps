const path = require('path');

const adminRoot = process.env.NODERED_ADMIN_ROOT || '/red';
const httpNodeRoot = process.env.NODERED_HTTP_NODE_ROOT || '/';
const classicDashboardPath = (process.env.NODERED_CLASSIC_DASHBOARD_PATH || '/ui').replace(/^\//, '');
const dashboard2Path = (process.env.NODERED_DASHBOARD2_PATH || '/dashboard').replace(/^\//, '');
const defaultPermissions = process.env.NODERED_DEFAULT_PERMISSIONS || 'read';
const userDir = process.env.NODE_RED_USER_DIR || '/data';
const projectsDir = process.env.NODERED_PROJECTS_DIR || '/data/projects';
const adminUsers = [];

if (process.env.NODERED_ADMIN_USER && process.env.NODERED_ADMIN_PASSWORD_BCRYPT) {
  adminUsers.push({
    username: process.env.NODERED_ADMIN_USER,
    password: process.env.NODERED_ADMIN_PASSWORD_BCRYPT,
    permissions: '*',
  });
}

if (
  (process.env.NODERED_VIEWER_ENABLED || 'true') !== 'false' &&
  process.env.NODERED_VIEWER_USER &&
  process.env.NODERED_VIEWER_PASSWORD_BCRYPT
) {
  adminUsers.push({
    username: process.env.NODERED_VIEWER_USER,
    password: process.env.NODERED_VIEWER_PASSWORD_BCRYPT,
    permissions: 'read',
  });
}

module.exports = {
  flowFile: process.env.NODERED_FLOW_FILE || 'flows.json',
  credentialSecret: process.env.NODERED_CREDENTIAL_SECRET || false,
  flowFilePretty: true,
  userDir,
  uiPort: Number(process.env.PORT || 1880),
  httpAdminRoot: adminRoot,
  httpNodeRoot,
  adminAuth: adminUsers.length
    ? {
        type: 'credentials',
        users: adminUsers,
        default: {
          permissions: defaultPermissions,
        },
      }
    : undefined,
  diagnostics: {
    enabled: true,
    ui: true,
  },
  runtimeState: {
    enabled: false,
    ui: false,
  },
  logging: {
    console: {
      level: process.env.NODERED_LOG_LEVEL || 'info',
      metrics: false,
      audit: true,
    },
  },
  exportGlobalContextKeys: false,
  functionExternalModules: true,
  functionGlobalContext: {
    fs: require('fs'),
    path,
    projectsDir,
  },
  editorTheme: {
    projects: {
      enabled: true,
      workflow: {
        mode: process.env.NODERED_PROJECTS_WORKFLOW_MODE || 'manual',
      },
    },
    codeEditor: {
      lib: 'monaco',
    },
    multiplayer: {
      enabled: false,
    },
  },
  ui: {
    path: classicDashboardPath,
    readOnly: defaultPermissions === 'read',
  },
  dashboard: {
    path: dashboard2Path,
  },
};
