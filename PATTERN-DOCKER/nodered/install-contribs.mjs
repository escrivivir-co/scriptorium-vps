import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';

const manifestPath = process.argv[2];
if (!manifestPath) {
  console.error('Usage: node install-contribs.mjs <manifest.json>');
  process.exit(1);
}

const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
const registryPackages = manifest.registryPackages ?? [];
const workspacePackages = manifest.workspacePackages ?? [];
const missingArtifacts = workspacePackages.flatMap((pkg) =>
  (pkg.smokeFiles ?? [])
    .map((relativePath) => ({
      packageName: pkg.name,
      relativePath,
      absolutePath: path.join(pkg.source, relativePath),
    }))
    .filter(({ absolutePath }) => !fs.existsSync(absolutePath)),
);

if (missingArtifacts.length) {
  console.error('Refusing to install local Node-RED contribs because build artifacts are missing:');
  missingArtifacts.forEach(({ packageName, relativePath }) => {
    console.error(` - ${packageName}: ${relativePath}`);
  });
  process.exit(1);
}

const allPackages = [...registryPackages, ...workspacePackages.map((pkg) => pkg.source)];

if (!allPackages.length) {
  console.log('No Node-RED contrib packages declared. Nothing to install.');
  process.exit(0);
}

console.log('Installing Node-RED packages declared in manifest:', allPackages);
execFileSync(
  'npm',
  ['install', '--unsafe-perm', '--no-fund', '--no-audit', ...allPackages],
  {
    cwd: process.env.NODE_RED_USER_DIR || '/data',
    stdio: 'inherit',
  },
);
