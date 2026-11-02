'use strict';
const fs = require('node:fs');
const path = require('node:path');

// Requires a devDependency during the build phase so single-stage --omit=dev fails without a builder stage
let tsVersion = 'unknown';
try {
  tsVersion = require('typescript').version;
} catch {
  console.error('BUILD ERROR: Necessary devDependencies missing. Run npm run build in the builder stage.');
  process.exit(1);
}

const distDir = path.join(__dirname, '..', 'dist');
fs.mkdirSync(distDir, { recursive: true });

const manifest = {
  builtAt: new Date().toISOString(),
  compilerCheck: `typescript-${tsVersion}`,
  commitSha: process.env.GITHUB_SHA || 'local-dev'
};

fs.writeFileSync(path.join(distDir, 'build-manifest.json'), JSON.stringify(manifest, null, 2));
console.log('Build manifest generated:', manifest);