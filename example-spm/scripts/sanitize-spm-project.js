const fs = require('node:fs');
const path = require('node:path');

const iosRoot = path.resolve(__dirname, '..', 'ios');
const projectRoot = path.join(iosRoot, 'CookieManagerExampleSpm.xcodeproj');
const projectPath = path.join(projectRoot, 'project.pbxproj');
const injectionPath = path.join(projectRoot, '.spm-injected.json');

// React Native 0.87.1 writes the current machine's absolute hermesc path into
// both generated files. Xcode resolves Hermes without it, so do not commit a
// developer- or CI-specific path.
const project = fs
  .readFileSync(projectPath, 'utf8')
  .replace(/^\s*HERMES_CLI_PATH = ".*";\r?\n/gm, '');
fs.writeFileSync(projectPath, project);

const injection = fs
  .readFileSync(injectionPath, 'utf8')
  .replace(/^\s*"HERMES_CLI_PATH",\r?\n/gm, '');
fs.writeFileSync(injectionPath, injection);
