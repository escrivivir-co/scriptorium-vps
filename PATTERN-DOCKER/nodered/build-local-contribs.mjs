import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';

const manifestPath = process.argv[2];
if (!manifestPath) {
  console.error('Usage: node build-local-contribs.mjs <manifest.json>');
  process.exit(1);
}

const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
const workspacePackages = manifest.workspacePackages ?? [];

for (const pkg of workspacePackages) {
  console.log(`\n📦 Preparing local package ${pkg.name} from ${pkg.source}`);
  execFileSync('npm', ['install', '--no-fund', '--no-audit'], {
    cwd: pkg.source,
    stdio: 'inherit',
  });

  if (pkg.buildCommand) {
    execFileSync('sh', ['-lc', pkg.buildCommand], {
      cwd: pkg.source,
      stdio: 'inherit',
    });
  }

  const missingSmokeFiles = (pkg.smokeFiles ?? [])
    .map((relativePath) => ({
      relativePath,
      absolutePath: path.join(pkg.source, relativePath),
    }))
    .filter(({ absolutePath }) => !fs.existsSync(absolutePath));

  if (missingSmokeFiles.length) {
    console.error(`❌ Package ${pkg.name} is missing build artifacts:`);
    missingSmokeFiles.forEach(({ relativePath }) => console.error(`   - ${relativePath}`));
    process.exit(1);
  }

  console.log(`✅ ${pkg.name} built successfully and smoke files are present.`);
}
