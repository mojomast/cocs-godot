// External probe: use the artifact's unchanged parser and ordinary source server.
import {readFileSync} from 'node:fs';
import {pathToFileURL} from 'node:url';
import {join} from 'node:path';
const [packagePath, ...args] = process.argv.slice(2);
const {options} = await import(pathToFileURL(join(packagePath, 'options.mjs')));
const plan = options(args, JSON.parse(readFileSync(join(packagePath, 'catalog.json'))));
const {createGameServer} = await import(pathToFileURL(join(packagePath, 'runtime/server/game-server.mjs')));
const game = createGameServer({historyPath:null, progressionPath:null});
await new Promise((resolve, reject) => {
  game.server.once('error', reject);
  game.server.listen(0, '127.0.0.1', resolve);
});
console.log('COMPACT_AUTHORITY_READY ' + JSON.stringify({plan, port:game.server.address().port}));
process.once('SIGTERM', async () => {
  for (const socket of game.wss.clients) socket.terminate();
  game.server.closeAllConnections();
  await game.close();
  console.log('COMPACT_AUTHORITY_CLOSED');
});
