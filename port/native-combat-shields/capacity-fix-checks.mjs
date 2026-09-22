// Re-run the delivered and independent fixtures without overwriting review
// history. The independent script/oracle are read-only inputs, not edited tests.
import {spawnSync} from 'node:child_process';
import {mkdirSync,writeFileSync,readFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import assert from 'node:assert/strict';
const root=fileURLToPath(new URL('../../',import.meta.url));
const godot='/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64';
const stamp=Date.now();
const out=fileURLToPath(new URL(`./evidence/capacity-fix/${stamp}/`,import.meta.url));
mkdirSync(out,{recursive:true});
const run=(name,cmd,args)=>{
  const result=spawnSync(cmd,args,{cwd:root,encoding:'utf8',timeout:180000});
  const text=(result.stdout??'')+(result.stderr??'');
  writeFileSync(`${out}/${name}.log`,text);
  console.log(`${name}: exit=${result.status}\n${text}`);
  assert.equal(result.status,0,`${name}: attempt retained at ${out}`);
  assert(!/SCRIPT ERROR|Parse Error|ERROR:|instances leaked|resources still in use/.test(text),`${name}: diagnostic failure retained`);
};
if(!process.argv.includes('--graphics-only')){
  run('delivered-headless',godot,['--headless','--path','godot','--script','res://tests/combat_shields/validate.gd']);
  run('capacity-headless',godot,['--headless','--path','godot','--script','res://tests/combat_shields/capacity.gd','--',`--output=${out}/capacity.json`]);
  run('live-source','node',['port/native-combat-shields/live-oracle.mjs']);
}
if(!process.argv.includes('--headless-only')){
  for(const [script,prefix,sizes] of [
    ['res://tests/combat_shields/graphics.gd','delivered',['960x640','1280x720']],
    ['res://tests/combat_expansion_independent/review.gd','independent',['960x640','1280x800']],
  ]) for(const size of sizes){
    const target=`${out}/${prefix}-${size}`;
    mkdirSync(target,{recursive:true});
    run(`${prefix}-${size}`,'xvfb-run',['-a','-s',`-screen 0 ${size}x24`,godot,'--path','godot','--rendering-method','gl_compatibility','--audio-driver','Dummy','--script',script,'--',`--size=${size}`,`--output=${target}`]);
    if(prefix==='independent'){
      const report=JSON.parse(readFileSync(`${target}/report.json`));
      const order=report.observations.find(o=>o.id==='SHIELD-CAP-ORDER');
      // The historical independent fixture records the defect, not a failing
      // assertion. Add positive regression assertions here without weakening it.
      assert.equal(order.first_16_unprotected.visible_shells,1);
      assert.equal(order.protected_first.visible_shells,1);
      assert.equal(order.first_16_unprotected.materials,1);
      assert.equal(order.protected_first.materials,1);
      assert.equal(order.first_16_unprotected.actors,17);
      assert.equal(order.protected_first.actors,17);
      writeFileSync(`${target}/allocation-fixed.json`,JSON.stringify({passed:true,sourceReport:'SHIELD-CAP-ORDER',normal:order.first_16_unprotected,reversed:order.protected_first},null,2)+'\n');
    }
  }
}
console.log(`SHIELD_CAPACITY_FIX_CHECKS_OK evidence=${out}`);
