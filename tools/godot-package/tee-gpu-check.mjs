// Append a harness's stdout/stderr to the shared log while showing it live.
import {spawn} from 'node:child_process';
import {createWriteStream} from 'node:fs';

const [logPath, binary, ...args] = process.argv.slice(2);
if (!logPath || !binary || !args.length) throw Error('log-path binary script [args...]');
const log = createWriteStream(logPath, {flags: 'a'});
const child = spawn(binary, args, {stdio: ['inherit', 'pipe', 'pipe']});
for (const stream of [child.stdout, child.stderr]) {
  stream.on('data', bytes => { process.stdout.write(bytes); log.write(bytes); });
}
child.on('error', error => { console.error(error); log.write(`${error}\n`); process.exitCode = 1; });
child.on('close', (code, signal) => {
  if (signal) { const line = `Harness terminated by ${signal}\n`; process.stdout.write(line); log.write(line); }
  if (!process.exitCode) process.exitCode = code ?? 1;
  log.end();
});
