// Measurement-only child: owns one native-arena authority and reports its own
// CPU usage so a parent harness can separate authority cost from client cost.
// This file is evidence tooling; it is never imported by shipped code.
//
// observeFlag: '0' no observer, '1' count frames, '2' count frames and begin the
// CPU window at the first reported source step (so one-time match construction
// is excluded from both harnesses).
import {createNativeArenaAuthority} from '../native-arenas/authority.mjs';

const [, , mapId = 'prism-foundry', bots = '2', seconds = '60', observeFlag = '0'] = process.argv;
const counts = {};
let beginUsage = null, beginUptime = 0;
const begin = () => {
  if (beginUsage !== null) return;
  beginUsage = process.cpuUsage(); beginUptime = process.uptime();
};
const observe = observeFlag === '0' ? undefined : row => {
  counts[row.direction] = (counts[row.direction] ?? 0) + 1;
  if (row.direction === 'step') counts.steps = (counts.steps ?? 0) + 1;
  if (row.direction === 'out' && row.frame?.type === 'snapshot') counts.snapshots = (counts.snapshots ?? 0) + 1;
  if (row.direction === 'in' && row.frame?.type === 'input') counts.inputs = (counts.inputs ?? 0) + 1;
  if (observeFlag === '2' && row.direction === 'step') begin();
};
const authority = await createNativeArenaAuthority({
  port: 0, host: '127.0.0.1', mapId, mode: 'deathmatch',
  bots: Number(bots), roundSeconds: Number(seconds), ...(observe ? {observe} : {}),
});
process.send({type: 'ready', endpoint: authority.endpoint, port: authority.port, pid: process.pid});
process.on('message', async message => {
  if (message === 'begin') { begin(); process.send({type: 'begun'}); return; }
  if (message !== 'stop') return;
  const usage = process.cpuUsage(beginUsage ?? undefined);
  process.send({type: 'cpu', usage, endedUptime: process.uptime(),
    beginUptime: beginUptime || 0, counts});
  await authority.close();
  process.exit(0);
});
