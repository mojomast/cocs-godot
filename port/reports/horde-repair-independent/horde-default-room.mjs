import {createGameServer} from '../../../server/game-server.mjs';
import {WebSocket} from 'ws';
import {once} from 'node:events';
import {writeFileSync} from 'node:fs';
import assert from 'node:assert/strict';
const game=createGameServer(),frames=[];
let ws,port;
try {
 await new Promise(r=>game.server.listen(0,'127.0.0.1',r));
 port=game.server.address().port;
 ws=new WebSocket(`ws://127.0.0.1:${port}`);
 ws.on('message',data=>frames.push(JSON.parse(String(data))));
 await once(ws,'open');
 const send=f=>ws.send(JSON.stringify(f));
 const wait=async predicate=>{const end=performance.now()+3000;while(!predicate()){assert(performance.now()<end,'bounded Room timeout');await new Promise(r=>setTimeout(r,10));}};
 send({type:'join',v:3,name:'Independent Horde review'});
 await wait(()=>frames.some(f=>f.type==='welcome'));
 assert.equal(frames.find(f=>f.type==='welcome').roomId,'local');
 send({type:'host',mapId:'meridian-exchange',config:{mode:'horde'}});
 await wait(()=>frames.some(f=>f.type==='error'));
 assert(frames.some(f=>f.type==='error'&&f.message==='single-player modes are local only'));
 assert.equal(game.registry.defaultRoom.config.mode,'deathmatch');
 assert.equal(game.registry.defaultRoom.match,null);
} finally {
 if(ws){const closed=once(ws,'close');ws.terminate();await closed;}
 const closed=once(game.server,'close');await game.close();await closed;
}
const result={status:'PASS',port,frames,serverClosed:!game.server.listening,sockets:game.wss.clients.size};
writeFileSync(new URL('default-room.json',import.meta.url),JSON.stringify(result,null,2)+'\n');
console.log(JSON.stringify(result));
