#!/usr/bin/env node
// Refs #3: BotMux can restart without terminating this container or its tmux.
import { spawn, spawnSync } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import {
  closeSync, existsSync, mkdirSync, openSync, readlinkSync, renameSync,
  symlinkSync, unlinkSync, writeFileSync,
} from 'node:fs';
import { homedir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const home = homedir();
const root = join(home, '.local', 'share', 'botmux');
const current = join(root, 'current');
const config = join(home, '.botmux');
const script = fileURLToPath(import.meta.url);

function run(command, args, timeout = 120_000) {
  // Lifecycle output can contain an admin login URL; retain it privately.
  const log = command.endsWith('/botmux')
    ? openSync(join(config, 'container-lifecycle.log'), 'a', 0o600) : null;
  let result;
  try {
    result = spawnSync(command, args, {
      stdio: log === null ? 'inherit' : ['ignore', log, log], timeout,
    });
  } finally {
    if (log !== null) closeSync(log);
  }
  if (result.error) throw result.error;
  if (result.status !== 0) {
    throw new Error(`${command} exited with ${result.status ?? result.signal}`);
  }
}

function version(value) {
  if (!/^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$/.test(value ?? '')) {
    throw new Error('Supply an exact BotMux version, for example 3.58.0.');
  }
  return value;
}

function selected() {
  return existsSync(current)
    ? resolve(dirname(current), readlinkSync(current)) : null;
}

function select(directory) {
  const temporary = `${current}.${randomUUID()}`;
  symlinkSync(directory, temporary);
  renameSync(temporary, current);
}

function pinLauncher() {
  const launcher = join(config, 'bin', 'botmux');
  mkdirSync(dirname(launcher), { recursive: true });
  const temporary = `${launcher}.${randomUUID()}`;
  writeFileSync(temporary,
    '#!/bin/sh\nexec "$HOME/.local/share/botmux/current/bin/botmux" "$@"\n',
    { mode: 0o755 });
  renameSync(temporary, launcher);
}

function executable(directory = current) {
  return join(directory, 'bin', 'botmux');
}

function install(target) {
  const directory = join(root, 'versions', version(target));
  const binary = executable(directory);
  const installed = existsSync(binary)
    ? spawnSync(binary, ['--version'], { encoding: 'utf8' }) : null;
  if (installed?.status !== 0 || installed.stdout.trim() !== target) {
    mkdirSync(directory, { recursive: true });
    run('npm', [
      'install', '--global', '--prefix', directory, `botmux@${target}`,
    ], 600_000);
  }
  const check = spawnSync(binary, ['--version'], { encoding: 'utf8' });
  if (check.status !== 0 || check.stdout.trim() !== target) {
    throw new Error('Installed BotMux did not report the requested version.');
  }
  return directory;
}

async function healthy() {
  const port = process.env.BOTMUX_DASHBOARD_PORT || '7891';
  for (let attempt = 0; attempt < 60; attempt++) {
    try {
      const response = await fetch(`http://127.0.0.1:${port}/__health`, {
        signal: AbortSignal.timeout(1000),
      });
      if (response.ok) return;
    } catch { /* Wait for the restarted dashboard. */ }
    await new Promise(resolveWait => setTimeout(resolveWait, 1000));
  }
  throw new Error('Dashboard did not recover within 60 seconds.');
}

async function change(target, restart) {
  const previous = selected();
  try {
    select(install(target));
  } finally {
    // npm postinstall rewrites this launcher before activation is committed.
    pinLauncher();
  }
  try {
    if (restart) {
      run(executable(), ['restart']);
      await healthy();
    }
  } catch (error) {
    if (previous) {
      select(previous);
      console.error('Previous version reselected. Fleet state was left unchanged; '
        + 'inspect lifecycle logs before explicitly starting or restarting it.');
    } else {
      unlinkSync(current);
    }
    throw error;
  }
  console.log(`BotMux ${target} selected; container and tmux were not restarted.`);
}

function locked(command, target) {
  run('flock', ['--nonblock', join(root, 'update.lock'), process.execPath,
    script, command, version(target)], 900_000);
}

async function serve() {
  if (!selected()) locked('__install', process.env.BOTMUX_VERSION);
  const bots = join(config, 'bots.json');
  if (!existsSync(bots)) {
    writeFileSync(bots, '[]\n', { flag: 'wx', mode: 0o600 });
  }
  try {
    run(executable(), ['start']);
  } catch (error) {
    console.error(`Normal startup failed: ${error.message}; starting recovery dashboard.`);
    background(['__supervisor']);
  }
  let stopping = false;
  let watchdog;
  const timer = setInterval(() => {
    if (stopping || watchdog) return;
    watchdog = background(['__watchdog']);
    watchdog.once('error', error => console.error(error.message));
    watchdog.once('close', () => { watchdog = undefined; });
  }, 15_000);
  const stop = () => {
    if (stopping) return;
    stopping = true;
    clearInterval(timer);
    watchdog?.kill('SIGTERM');
    try {
      run(executable(), ['stop'], 110_000);
      process.exit(0);
    } catch (error) {
      console.error(error.message);
      process.exit(1);
    }
  };
  process.on('SIGTERM', stop);
  process.on('SIGINT', stop);
}

function background(args) {
  const log = openSync(join(config, 'container-lifecycle.log'), 'a', 0o600);
  try {
    const child = spawn(executable(), args, { stdio: ['ignore', log, log] });
    child.once('error', error => console.error(error.message));
    return child;
  } finally {
    closeSync(log);
  }
}

mkdirSync(root, { recursive: true });
mkdirSync(config, { recursive: true });
const [command, target] = process.argv.slice(2);
try {
  if (command === 'serve') await serve();
  else if (command === 'install') locked('__install', target);
  else if (command === 'update') locked('__update', target);
  else if (command === '__install') await change(target, false);
  else if (command === '__update') await change(target, true);
  else throw new Error('Usage: botmux-runtime serve | install VERSION | update VERSION');
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}
