import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  chmodSync, mkdirSync, mkdtempSync, readFileSync, readlinkSync, rmSync,
  statSync, symlinkSync, writeFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const runtime = fileURLToPath(new URL('./runtime.mjs', import.meta.url));

function fixture(t) {
  const home = mkdtempSync(join(tmpdir(), 'botmux-runtime-test-'));
  t.after(() => rmSync(home, { recursive: true, force: true }));
  const root = join(home, '.local', 'share', 'botmux');
  mkdirSync(join(home, '.botmux'), { recursive: true });
  for (const version of ['3.57.2', '3.58.0']) {
    const bin = join(root, 'versions', version, 'bin');
    mkdirSync(bin, { recursive: true });
    const script = `#!/bin/sh
case "$1" in
  --version) echo '${version}' ;;
  restart)
    echo ADMIN_LOGIN_SECRET
    echo '${version} restart' >> "$HOME/events"
    if [ '${version}' = '3.58.0' ]; then
      echo stopped > "$HOME/operator-state"
      exit 1
    fi
    echo running > "$HOME/operator-state"
    ;;
esac
`;
    writeFileSync(join(bin, 'botmux'), script);
    chmodSync(join(bin, 'botmux'), 0o755);
  }
  const previous = join(root, 'versions', '3.57.2');
  const current = join(root, 'current');
  symlinkSync(previous, current);
  const invoke = (...args) => spawnSync(process.execPath, [runtime, ...args], {
    env: { ...process.env, HOME: home }, encoding: 'utf8',
  });
  return { home, root, previous, current, invoke };
}

test('failed activation preserves an intervening operator stop', t => {
  const f = fixture(t);
  const result = f.invoke('__update', '3.58.0');
  assert.equal(result.status, 1);
  assert.equal(readlinkSync(f.current), f.previous);
  assert.equal(readFileSync(join(f.home, 'operator-state'), 'utf8').trim(), 'stopped');
  assert.equal(readFileSync(join(f.home, 'events'), 'utf8'), '3.58.0 restart\n');
  assert.equal((result.stdout + result.stderr).includes('ADMIN_LOGIN_SECRET'), false);
  const log = join(f.home, '.botmux', 'container-lifecycle.log');
  assert.match(readFileSync(log, 'utf8'), /ADMIN_LOGIN_SECRET/);
  assert.equal(statSync(log).mode & 0o777, 0o600);
});

test('invalid version input leaves the selected installation untouched', t => {
  const f = fixture(t);
  assert.equal(f.invoke('update', '../different-home').status, 1);
  assert.equal(readlinkSync(f.current), f.previous);
});

test('failed package installation cannot replace the selected version', t => {
  const f = fixture(t);
  const bin = join(f.home, 'test-bin');
  mkdirSync(bin);
  mkdirSync(join(f.home, '.botmux', 'bin'));
  writeFileSync(join(bin, 'npm'),
    '#!/bin/sh\nprintf "broken launcher\\n" > "$HOME/.botmux/bin/botmux"\nexit 1\n',
    { mode: 0o755 });
  const result = spawnSync(process.execPath, [runtime, '__update', '9.9.9'], {
    env: { ...process.env, HOME: f.home, PATH: bin }, encoding: 'utf8',
  });
  assert.equal(result.status, 1);
  assert.equal(readlinkSync(f.current), f.previous);
  const launcher = spawnSync(join(f.home, '.botmux', 'bin', 'botmux'), ['--version'], {
    env: { ...process.env, HOME: f.home }, encoding: 'utf8',
  });
  assert.equal(launcher.status, 0);
  assert.equal(launcher.stdout.trim(), '3.57.2');
});
