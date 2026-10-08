import {spawn} from 'node:child_process';

export function weatherSpawnPlan(platform, binary, args) {
  return platform === 'win32'
    ? {command: binary, args}
    : {command: 'xvfb-run', args: ['-a', binary, ...args]};
}

export function hordeWindowArgs(platform, display) {
  const windowed = platform === 'win32' || Boolean(display);
  return [
    ...(windowed ? [] : ['--headless']),
    ...(windowed ? ['--rendering-method', 'gl_compatibility', '--audio-driver', 'Dummy', '--windowed', '--resolution', '640x480'] : []),
  ];
}

// Windows has no POSIX process-group signal; taskkill includes any engine children.
export function killWindowsTree(child) {
  if (!child || child.exitCode !== null || child.signalCode !== null) return;
  if (!child.pid) { child.kill(); return; }
  const killer = spawn('taskkill', ['/PID', String(child.pid), '/T', '/F'], {windowsHide: true, stdio: 'ignore'});
  killer.once('error', () => child.kill());
  killer.once('exit', code => { if (code !== 0) child.kill(); });
}
