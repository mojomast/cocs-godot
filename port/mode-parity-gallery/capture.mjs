#!/usr/bin/env node
// Serial rendered evidence from the actual menu/native DM/Horde scenes.
// Authorities are real loopback adapters. The Horde death is test-only staged
// through the source Match.damage method after the client lines up a real NPC;
// the screenshots, event, fall and blood burst are verified before publication.
import {spawn, execFileSync} from 'node:child_process';
import {createInterface} from 'node:readline';
import {createHash} from 'node:crypto';
import {existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync} from 'node:fs';
import {resolve, join} from 'node:path';
import {Match} from '../../game/core.mjs';
import {createAuthority as createHordeAuthority} from '../native-horde/authority.mjs';
import {createAuthority as createArenaAuthority} from '../native-arenas/authority.mjs';

const root = resolve(import.meta.dirname, '../..');
const disk = process.env.GALLERY_TMP ?? (existsSync('/home/mojo/.tmp-on-disk/opencode')
  ? '/home/mojo/.tmp-on-disk/opencode' : '/tmp/opencode');
const binary = process.env.GODOT_BIN;
if (!binary || !existsSync(binary)) throw Error('Set GODOT_BIN to the pinned Godot 4.5.2 executable');
const output = resolve(process.env.GALLERY_OUT ?? join(root, 'port/mode-parity-gallery/evidence'));
mkdirSync(output, {recursive:true});
const plan = process.argv[2] === 'all' || !process.argv[2] ? ['menu','dm-diagnostics','dm-fire','horde'] : [process.argv[2]];
if (plan.some(item => !['menu','dm-diagnostics','dm-fire','horde'].includes(item))) throw Error('Choose all, menu, dm-diagnostics, dm-fire or horde');
const head = execFileSync('git',['rev-parse','HEAD'],{cwd:root,encoding:'utf8'}).trim();
const source = JSON.parse(readFileSync(join(root,'port/contracts/source-lock.json'))).source_commit;
const originalStep = Match.prototype.step;
let liveHorde = null;

function pngInfo(file) {
  const bytes = readFileSync(file);
  if (bytes.readUInt32BE(0) !== 0x89504e47) throw Error(`Not a PNG: ${file}`);
  return {width:bytes.readUInt32BE(16),height:bytes.readUInt32BE(20),sha256:createHash('sha256').update(bytes).digest('hex')};
}

async function run(which) {
  const horde = which === 'horde', menu = which === 'menu', bots = 4;
  const size = [1280,800];
  const authorityEvents = [];
  const authority = menu ? null : horde ? createHordeAuthority() : createArenaAuthority({mapId:'prism-foundry',bots,roundSeconds:180,debug:false,
    observe:record => { if (record.direction === 'transport-error' || record.direction === 'control-reset') authorityEvents.push(record); }});
  const temp = mkdtempSync(join(disk, 'mode-parity-gallery-runtime-'));
  let child, timeout, triggered = false, captureError = null;
  const shots = [], log = [];
  try {
    if (authority) await new Promise((ok,fail) => {
      authority.server.once('error',fail);
      authority.server.listen(0,'127.0.0.1',ok);
    });
    if (horde) {
      Match.prototype.step = function (...args) {
        const result = originalStep.apply(this,args);
        if (this.modeState?.kind === 'horde') liveHorde = this;
        return result;
      };
    }
    const scene = menu ? 'menu' : horde ? 'horde' : 'native-dm';
    const map = horde ? (process.env.GALLERY_HORDE_MAP ?? 'meridian-exchange') : 'prism-foundry';
    const endpoint = authority ? `ws://127.0.0.1:${authority.server.address().port}${horde ? '' : '/native-arenas'}` : '';
    const args = ['-B','tools/godot-dev/xvfb_run.py',binary,'--path','godot',
      '--audio-driver','Dummy','--rendering-method','gl_compatibility','--resolution','1280x800',
      '--script','res://tests/mode_parity_gallery/capture.gd','--',
      `--scene=${scene}`,`--out=${output}`,`--map=${map}`,`--size=${size.join('x')}`,
      ...(menu ? [] : horde ? [`--endpoint=${endpoint}`,'--waves=10']
        : [`--endpoint=${endpoint}`,`--bots=${bots}`,'--round-seconds=180','--autostart',
          ...(which === 'dm-diagnostics' ? ['--diagnostics'] : [])])];
    child = spawn('python3',args,{cwd:root,env:{...process.env,
      XDG_DATA_HOME:join(temp,'data'),XDG_CONFIG_HOME:join(temp,'config'),XDG_CACHE_HOME:join(temp,'cache')},
    stdio:['ignore','pipe','pipe'],detached:true});
    const line = text => {
      log.push(text);
      if (text.startsWith('GALLERY_SHOT ')) shots.push(JSON.parse(text.slice('GALLERY_SHOT '.length)));
      if (horde && text.startsWith('GALLERY_READY ') && !triggered) {
        triggered = true;
        const {actor: id} = JSON.parse(text.slice('GALLERY_READY '.length));
        const enemy = liveHorde?.actors.find(a => a.id === id && a.isNpc && a.health > 0);
        if (!enemy || !liveHorde?.actors[0]) {
          captureError = `Horde source NPC ${id} is no longer alive`;
          try { process.kill(-child.pid,'SIGTERM'); } catch {}
          return;
        }
        const damage = enemy.health + (enemy.armor ?? 0) + 1000;
        liveHorde.damage(enemy,damage,liveHorde.actors[0]);
        log.push(`GALLERY_STAGED_SOURCE_DAMAGE ${JSON.stringify({actor:id,damage,remaining_health:enemy.health})}`);
      }
    };
    for (const stream of [child.stdout,child.stderr]) createInterface({input:stream}).on('line',line);
    const outcome = await new Promise((done,fail) => {
      child.once('error',fail);
      child.once('exit',(code,signal) => done({code,signal}));
      timeout = setTimeout(() => {
        try { process.kill(-child.pid,'SIGKILL'); } catch {}
      },180000);
    });
    if (captureError || outcome.code !== 0 || !log.includes(`GALLERY_DONE ${scene}`) || log.some(row => row.startsWith('GALLERY_FAIL'))) {
      throw Error(`Capture ${which} failed: ${captureError ?? JSON.stringify(outcome)}\nAuthority: ${JSON.stringify(authorityEvents.slice(-8))}\n${log.slice(-30).join('\n')}`);
    }
    const expected = menu ? ['menu-native-24'] : horde ? ['horde-before','horde-before-detail','horde-impact','horde-impact-detail','horde-death','horde-death-detail']
      : which === 'dm-diagnostics' ? ['dm-diagnostics','dm-roster'] : ['dm-barrel-fire'];
    if (shots.length !== expected.length || expected.some(name => !shots.some(shot => shot.name === name))) {
      throw Error(`Capture ${which} did not produce ${expected}: ${JSON.stringify(shots)}`);
    }
    const files = shots.map(shot => {
      const info = pngInfo(shot.path);
      const expectedSize = shot.name.endsWith('-detail') ? [880,640] : size;
      if (info.width !== expectedSize[0] || info.height !== expectedSize[1]) throw Error(`Wrong dimensions: ${shot.path}`);
      return {...shot, ...info, path:shot.name+'.png'};
    });
    console.log(`GALLERY_CAPTURE_OK ${JSON.stringify({which,files:files.map(f => f.path),source,head,staged_damage:triggered})}`);
    return files;
  } finally {
    clearTimeout(timeout);
    Match.prototype.step = originalStep;
    liveHorde = null;
    if (child?.exitCode === null) { try { process.kill(-child.pid,'SIGKILL'); } catch {} }
    await authority?.close();
    writeFileSync(join(output,`${which}.log`),log.join('\n')+'\n');
    rmSync(temp,{recursive:true,force:true});
  }
}

const files = [];
for (const which of plan) files.push(...await run(which));
const result = {schema:1,label:'software-rendered project captures; no hardware FPS verdict',
  scene_runtime_commit:head,source_commit:source,godot:execFileSync(binary,['--version'],{encoding:'utf8'}).trim(),
  renderer:'Godot 4.5.2 GL Compatibility on Xvfb / llvmpipe',
  horde_staging:'One test-only source Match.damage call against a real wave NPC; subsequent death, corpse and blood are received from the authority.',
  files};
writeFileSync(join(output,'captures.json'),JSON.stringify(result,null,2)+'\n');
console.log(`GALLERY_COMPLETE ${JSON.stringify({images:files.length,output,head,source})}`);
