// In-game conveniences for an owned single-human campaign/Horde session.
// No source configuration or NPC seat is changed. The normal simulation is
// untouched until a player explicitly enables a cheat or opens the menu.
import {floorAt, obstructed} from '../../game/core.mjs';

const TOGGLES = ['invulnerable', 'unlimitedAmmo', 'flight'];
const ACTIONS = [...TOGGLES, 'weapons', 'heal', 'clear', 'pause'];
export const soloCheatPreferences = () => ({invulnerable:false, unlimitedAmmo:false, flight:false});

export function parseSoloCheat(frame) {
  if (!frame || typeof frame !== 'object' || Array.isArray(frame) ||
      Object.keys(frame).some(key => !['type','v','action','enabled','inputEpoch'].includes(key)) ||
      frame.type !== 'solo-cheat' || frame.v !== 1 || !ACTIONS.includes(frame.action) ||
      !Number.isSafeInteger(frame.inputEpoch) || frame.inputEpoch < 1) throw new TypeError('Invalid solo cheat command');
  const toggle = TOGGLES.includes(frame.action) || frame.action === 'pause';
  if (toggle ? typeof frame.enabled !== 'boolean' : frame.enabled !== undefined) throw new TypeError('Invalid solo cheat value');
  return {action:frame.action, enabled:frame.enabled, inputEpoch:frame.inputEpoch};
}

export function attachSoloCheats(match, preferences = soloCheatPreferences()) {
  if (match.humanCount !== 1 || !['campaign','horde'].includes(match.config.mode)) throw new TypeError('Solo cheats require a single-player match');
  const state = {available:true, version:1, paused:false, ...preferences, revision:0, notice:''};
  const player = () => match.actors.find(actor => actor.id === 0 && !actor.isNpc);
  const pose = actor => ({x:actor.x, y:actor.y, z:actor.z});
  let takeoff = pose(player());
  const damage = match.damage, fall = match.fall, step = match.step, snapshot = match.snapshot;
  function setPose(actor, position) {
    Object.assign(actor, position, {vx:0,vy:0,vz:0,sliding:false,slideTimer:0,jumpBuffer:0,jumpHeld:false});
  }
  function landing(actor) {
    const y = floorAt(actor.x,actor.z,match.arena);
    return Number.isFinite(y) && y > (match.arena.voidY ?? -1000) && !obstructed(actor.x,y,actor.z,.65,match.arena)
      ? {x:actor.x,y,z:actor.z} : takeoff;
  }
  function refill(actor, all = false) {
    actor.ammo.forEach((amount,index) => {
      if (!all && !(amount > 0 || index === actor.weapon)) return;
      const weapon = match.weaponForIndex(actor,index);
      if (weapon?.cap > 0) actor.ammo[index] = weapon.cap;
    });
  }
  function heal(actor) {actor.health = actor.maxHealth; actor.armor = Math.max(actor.armor,100);}
  match.damage = function(target, amount, ...args) {
    if (target === player() && state.invulnerable && amount > 0) return;
    return damage.call(this,target,amount,...args);
  };
  match.fall = function(actor, ...args) {
    if (actor === player() && (state.invulnerable || state.flight)) {
      setPose(actor,takeoff); actor.grounded = !state.flight;
      return;
    }
    return fall.call(this,actor,...args);
  };
  match.step = function(dt, inputs = {}) {
    if (state.paused) return;
    const actor = player();
    if (!actor || actor.health <= 0 || this.over) return step.call(this,dt,inputs);
    if (!state.flight && actor.grounded) takeoff = pose(actor);
    if (state.unlimitedAmmo) refill(actor);
    const controls = inputs.inputs?.[0] ?? {};
    const from = pose(actor);
    if (state.flight) actor.vx=actor.vy=actor.vz=0;
    // The debug flight position is owned here. Source combat still runs, with
    // neutral movement for this seat; source NPC movement is never intercepted.
    const sample = state.flight ? {...inputs, inputs:{...inputs.inputs, 0:{...controls,x:0,z:0,jump:false,crouch:false,mobility:false}}} : inputs;
    const result = step.call(this,dt,sample);
    if (state.flight && actor.health > 0) {
      const x = controls.x || 0, z = controls.z || 0;
      const y = Number(controls.jump === true) - Number(controls.crouch === true);
      const length = Math.max(1,Math.hypot(x,y,z)), speed = controls.sprint ? 24 : 12;
      const bounds = this.arena.bounds;
      const clamp = (value,min,max) => Math.max(min,Math.min(max,value));
      setPose(actor,{x:clamp(from.x+x/length*speed*dt,bounds.minX+.8,bounds.maxX-.8),
        y:clamp(from.y+y/length*speed*dt,Math.max((this.arena.voidY ?? -30)+3,-100),180),
        z:clamp(from.z+z/length*speed*dt,bounds.minZ+.8,bounds.maxZ-.8)});
      actor.grounded = false;
      actor.crouching = false;
      actor.vx=(actor.x-from.x)/dt;actor.vy=(actor.y-from.y)/dt;actor.vz=(actor.z-from.z)/dt;
    }
    if (state.unlimitedAmmo && actor.health > 0) refill(actor);
    return result;
  };
  match.snapshot = function() {return {...snapshot.call(this),soloCheats:{...state}};};
  return {
    state,
    apply({action,enabled}) {
      const actor = player();
      if (!actor || actor.health <= 0 || match.over) return false;
      if (TOGGLES.includes(action)) {
        if (action === 'flight' && enabled && !state.flight) takeoff = pose(actor);
        if (action === 'flight' && !enabled && state.flight) {setPose(actor,landing(actor));actor.grounded=true;}
        state[action] = enabled; preferences[action] = enabled;
        if (action === 'invulnerable' && enabled) heal(actor);
        if (action === 'unlimitedAmmo' && enabled) refill(actor);
      } else if (action === 'weapons') refill(actor,true);
      else if (action === 'heal') heal(actor);
      else if (action === 'pause') state.paused = enabled;
      else if (action === 'clear') {
        if (state.flight) {setPose(actor,landing(actor));actor.grounded=true;}
        for (const key of TOGGLES) {state[key]=false;preferences[key]=false;}
      } else throw new TypeError('Unknown solo cheat action');
      state.revision++;
      state.notice = action === 'weapons' ? 'All ten weapons granted' : action === 'heal' ? 'Health and armor restored' : action === 'clear' ? 'Cheats switched off' : '';
      return true;
    },
  };
}
