const { execFileSync } = require('node:child_process');
const path = require('node:path');

const projectRoot = path.resolve(__dirname, '..');
const cliPackagePath = require.resolve(
  '@react-native-community/cli/package.json',
  { paths: [projectRoot] }
);
const cliPackage = require(cliPackagePath);
const cliBin =
  typeof cliPackage.bin === 'string'
    ? cliPackage.bin
    : (cliPackage.bin['rnc-cli'] ?? Object.values(cliPackage.bin)[0]);

const output = execFileSync(
  process.execPath,
  [path.resolve(path.dirname(cliPackagePath), cliBin), 'config'],
  {
    cwd: projectRoot,
    encoding: 'utf8',
    maxBuffer: 64 * 1024 * 1024,
  }
);
const config = JSON.parse(output);

// Community CLI 20.2 discovers iOS projects through a Podfile. Supply the
// project metadata explicitly after this example has migrated to SwiftPM.
config.project.ios = {
  sourceDir: path.join(projectRoot, 'ios'),
  xcodeProject: {
    name: 'CookieManagerExampleSpm.xcodeproj',
    path: '.',
    isWorkspace: false,
  },
  automaticPodsInstallation: false,
  assets: [],
};

process.stdout.write(JSON.stringify(config));
