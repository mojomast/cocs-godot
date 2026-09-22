// Minimal bounded WebSocket helper for this route's authority tests.
import {WebSocket} from 'ws';

export async function connect(endpoint, options) {
  const ws = new WebSocket(endpoint, options);
  const frames = [], waiters = new Set();
  ws.on('message', bytes => {
    frames.push(JSON.parse(String(bytes)));
    for (const notify of [...waiters]) notify();
  });
  await new Promise((resolve, reject) => { ws.once('open', resolve); ws.once('error', reject); });
  ws.on('error', () => {});
  return {ws, frames, send(frame) { ws.send(JSON.stringify(frame)); },
    wait(predicate, {after = 0, timeout = 10000} = {}) {
      return new Promise((resolve, reject) => {
        const finish = (error, frame) => {
          clearTimeout(timer); waiters.delete(check); ws.off('close', closed);
          error ? reject(error) : resolve(frame);
        };
        const check = () => { const frame = frames.slice(after).find(predicate); if (frame) finish(null, frame); };
        const closed = () => finish(new Error('Socket closed while waiting for frame'));
        const timer = setTimeout(() => finish(new Error(`Frame timeout; recent types: ${frames.slice(-10).map(f => f.type)}`)), timeout);
        waiters.add(check); ws.once('close', closed); check();
      });
    },
  };
}

export async function rejected(endpoint, options, send) {
  const ws = new WebSocket(endpoint, options);
  ws.on('error', () => {});
  const closed = new Promise((resolve, reject) => {
    const timer = setTimeout(() => { ws.terminate(); reject(new Error('Rejection timeout')); }, 5000);
    ws.once('close', () => { clearTimeout(timer); resolve(); });
  });
  if (send) ws.once('open', () => send(ws));
  await closed;
}
