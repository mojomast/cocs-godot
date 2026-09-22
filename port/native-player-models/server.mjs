// Owned normal-rate authority, unchanged createGameServer defaults. Private staging only.
import {createGameServer} from '../../server/game-server.mjs';
import {writeFileSync} from 'node:fs';
const game=createGameServer({historyPath:null,progressionPath:null});
await new Promise((resolve,reject)=>{game.server.once('error',reject);game.server.listen(0,'127.0.0.1',resolve)});
const port=game.server.address().port;
writeFileSync(process.argv[2],JSON.stringify({port}));
console.log('PLAYER_MODEL_SERVER_READY '+port);
let closing=false;
async function stop(){if(closing)return;closing=true;await game.close();process.exit(0)}
process.on('SIGTERM',stop);process.on('SIGINT',stop);
