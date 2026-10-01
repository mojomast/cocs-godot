import {Match, floorAt, obstructed} from './derived/core.mjs';
import {readWorld,worldEntry} from './catalog.mjs';

// Room factory receives the same constructor args as locked Match. It swaps
// only the arena assignment before floor/nav/objective/actor construction.
export function worldMatchClass(mapId,mode){
  worldEntry(mapId,mode);
  const data=readWorld(mapId),arena=data.arena;
  let assigned=false;
  return class WorldMatch extends Match {
    get arena(){return arena;}
    set arena(_fallback){if(assigned)throw Error('World arena reassignment');assigned=true;}
    constructor(character,harness,random,id,config){
      super(character,harness,random,id,config);
      if(!assigned||id!==mapId||this.arena!==arena||this.snapshot().mapId!==mapId||this.config.mode!==mode)throw Error('World source-match constructor drift');
      for(const actor of this.actors)if(floorAt(actor.x,actor.z,arena)===null||obstructed(actor.x,actor.y,actor.z,.65,arena))throw Error('World actor spawned without clearance');
    }
  };
}
