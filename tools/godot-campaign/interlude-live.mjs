// Real authority/protocol + native client, serialized over eight checkpoint fixtures.
import {spawn} from 'node:child_process';
import {createAuthority} from '../../port/native-campaign/authority.mjs';
import {createCampaignMatch} from '../../port/native-campaign/match.mjs';
import {CAMPAIGN_MAP_IDS,loadCampaignMap} from '../../port/native-campaign/maps.mjs';
import {interludeDefinitions} from '../../port/native-campaign/interlude-definitions.mjs';
const godot=process.argv[2];
if(!godot)throw Error('Godot binary required');
for(const mapId of CAMPAIGN_MAP_IDS)for(const def of interludeDefinitions(loadCampaignMap(mapId))){
  let inputs=0,claims=0;
  const authority=createAuthority({mapId,random:()=>.5,
    matchFactory:options=>createCampaignMatch({...options,checkpoint:def.step,checkpointPoint:def.entry}),
    observe:record=>{if(record.direction==='in'&&record.frame.type==='input')inputs++;
      if(record.direction==='out'&&record.frame.state?.campaign.interludes.beats.find(b=>b.id===def.id)?.completed)claims++;}});
  await new Promise(resolve=>authority.server.listen(0,'127.0.0.1',resolve));
  try{
    const code=await new Promise((resolve,reject)=>{
      const child=spawn(godot,['--headless','--path','godot','--script','res://tests/campaign/interlude_live.gd','--',
        `--endpoint=ws://127.0.0.1:${authority.server.address().port}`,`--map=${mapId}`,`--beat=${def.id}`],
        {stdio:'inherit',env:{...process.env,LP_NUM_THREADS:'1'}});
      child.on('error',reject);child.on('exit',resolve);
    });
    if(code!==0||inputs<20||claims<1)throw Error(`Native live failed: ${mapId}/${def.id} code=${code}`);
    console.log('INTERLUDE_LIVE_AUTHORITY_OK',mapId,def.id,{inputs,completedSnapshots:claims});
  }finally{await authority.close();}
}
