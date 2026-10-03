// Test-only initial placement around a shipped map spawn. No post-setup actor writes.
import {writeFileSync, appendFileSync, renameSync} from 'node:fs';
import {resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

export function setup(match, scenario) {
  if (match.time !== 0 || match.actors.length !== 2) throw Error('Expected unstepped two-actor match');
  const [local, target] = match.actors;
  // Clear, flat western perimeter: initial capture click points SOUTH, away from target.
  Object.assign(local, {x:-44, y:0, z:-34, yaw:Math.PI, pitch:0, vx:0, vy:0, vz:0,
    health:100, armor:0, protection:0, grounded:true});
  Object.assign(target, {x:-44, y:0, z:-35.2, yaw:0, pitch:0, vx:0, vy:0, vz:0,
    health:100, armor:0, protection:scenario === 'blocked' ? 25 : 0, grounded:true, bot:false});
  return {kind:'setup', scenario, sourceTime:match.time, map:match.arena.id,
    note:'One initial legal placement; passive target. Protection only in labelled blocked fixture.',
    actors:[local,target].map(a=>({id:a.id,x:a.x,y:a.y,z:a.z,yaw:a.yaw,health:a.health,armor:a.armor,protection:a.protection,bot:a.bot}))};
}

async function main() {
  const {createGameServer} = await import('../../server/game-server.mjs');
  const [ready, output, scenario = 'chain'] = process.argv.slice(2);
  if (!ready || !output || !['chain','blocked'].includes(scenario)) throw Error('ready output chain|blocked required');
  const game = createGameServer({historyPath:null, progressionPath:null, random:()=>.5});
  const installed = new WeakSet(), seen = new Set();
  const report = record => appendFileSync(resolve(output,'authority.jsonl'), JSON.stringify({...record,wallMs:performance.now()})+'\n');
  const tick = game.registry.tickAll.bind(game.registry);
  game.registry.tickAll = dt => {
    for (const room of game.registry.rooms.values()) {
      if (!room.match || installed.has(room.match)) continue;
      report(setup(room.match, scenario));
      installed.add(room.match);
      // Observe ordinary wire input, then delegate unchanged to production validation.
      const input = room.input.bind(room);
      room.input = (peer, value) => {
        report({kind:'input', peer, sourceTime:room.match.time, envelope:value, input:value.input ?? value});
        return input(peer,value);
      };
    }
    tick(dt);
    for (const room of game.registry.rooms.values()) {
      if (!room.match) continue;
      for (const event of room.match.events) {
        if (event.type !== 'melee' || seen.has(event.id)) continue;
        seen.add(event.id);
        report({kind:'accepted',event,health:room.match.actors.map(a=>({id:a.id,health:a.health,x:a.x,z:a.z}))});
      }
    }
  };
  await new Promise((done, fail)=>{game.server.once('error',fail);game.server.listen(0,'127.0.0.1',done);});
  writeFileSync(ready+'.tmp', JSON.stringify({port:game.server.address().port}));
  renameSync(ready+'.tmp',ready);
  let closing = false;
  const stop = async () => {if(closing)return;closing=true;await game.close();process.exit(0);};
  process.on('SIGTERM',stop);process.on('SIGINT',stop);
  setTimeout(()=>{report({kind:'deadline'});stop();},60000).unref();
}
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) await main();
