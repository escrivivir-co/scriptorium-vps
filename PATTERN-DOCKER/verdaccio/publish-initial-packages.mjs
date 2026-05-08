import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';

const manifestPath = process.argv[2] || path.resolve('publish-initial-packages.manifest.json');
const workspaceRoot = process.env.WORKSPACE_ROOT || process.cwd();
const mode = process.env.PUBLISH_MODE || 'dry-run';
const registry = process.env.VERDACCIO_REGISTRY || 'https://npm.scriptorium.escrivivir.co/';

if (!fs.existsSync(manifestPath)) {
  throw new Error(`Manifest not found: ${manifestPath}`);
}

const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
const stagingRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'aleph-verdaccio-'));

function copyTree(srcRelativePath) {
  const src = path.join(workspaceRoot, srcRelativePath);
  const dest = path.join(stagingRoot, srcRelativePath);
  fs.mkdirSync(path.dirname(dest), { recursive: true });
  fs.cpSync(src, dest, {
    recursive: true,
    filter: (entry) => !entry.includes(`${path.sep}node_modules`) && !entry.includes(`${path.sep}.git`),
  });
  return dest;
}

for (const pkg of manifest.packages) {
  if (pkg.status === 'blocked') {
    console.log(`⏭️  Skipping ${pkg.id}: ${pkg.reason}`);
    continue;
  }

  const stagedDir = copyTree(pkg.workspaceRelativeSource);
  for (const supportFile of pkg.supportFiles || []) {
    copyTree(supportFile);
  }

  execFileSync('npm', ['install', '--no-fund', '--no-audit'], {
    cwd: stagedDir,
    stdio: 'inherit',
  });

  if (pkg.buildCommand) {
    execFileSync('sh', ['-lc', pkg.buildCommand], {
      cwd: stagedDir,
      stdio: 'inherit',
    });
  }

  const missingSmoke = (pkg.smokeFiles || []).filter((relativePath) => !fs.existsSync(path.join(stagedDir, relativePath)));
  if (missingSmoke.length) {
    throw new Error(`${pkg.id} missing smoke artifacts: ${missingSmoke.join(', ')}`);
  }

  const packageJsonPath = path.join(stagedDir, 'package.json');
  const packageJson = JSON.parse(fs.readFileSync(packageJsonPath, 'utf8'));
  packageJson.name = pkg.publishName;
  delete packageJson.private;
  if (pkg.dependencyOverrides) {
    packageJson.dependencies = {
      ...(packageJson.dependencies || {}),
      ...pkg.dependencyOverrides,
    };
  }
  packageJson.publishConfig = {
    ...(packageJson.publishConfig || {}),
    registry,
  };
  fs.writeFileSync(packageJsonPath, JSON.stringify(packageJson, null, 2));

  const publishArgs = ['publish', '--registry', registry];
  if (mode !== 'publish') {
    publishArgs.push('--dry-run');
  }

  console.log(`🚀 ${mode === 'publish' ? 'Publishing' : 'Dry-running'} ${pkg.publishName}`);
  execFileSync('npm', publishArgs, {
    cwd: stagedDir,
    stdio: 'inherit',
    env: {
      ...process.env,
      npm_config_registry: registry,
    },
  });
}

console.log(`✅ Verdaccio publish pipeline finished in ${stagingRoot}`);
