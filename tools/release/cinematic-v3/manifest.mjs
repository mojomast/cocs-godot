// Shot intent is not acceptance. Positions resolve from hash-checked production recipes.
export const chapters = [
  ['rootfall-verge','e45bf33d629e187b5679fc859451dcc18c35275ca93d8b25a5f77424cca0bddf','Canopy / nursery / broken repeater'],
  ['siltwake-crossing','3404e8bf56badeefe197351e9cb6f8d81146cbd96547026fa7209258093c62a7','Riverworks / waterwheel / ferry'],
  ['emberline-ascent','7fa1666dc7d0a238a77eadf01db44574dd5bbf93f00154cd1252b103d08d6421','Cooling terraces / condenser / furnace'],
  ['crown-array','8d6ace0fcda6470d5e2fd656ee0eab3936fc2e6a5c273021a5116df4d2c62d3e','Receiver crown / choir / garden'],
].map(([id,geometryHash,identity])=>({id,geometryHash,identity}));
const shot=(id,chapter,seconds,kind,extra={})=>({id,map:chapters[chapter].id,seconds,kind,
  camera:'spline',evidence:'staged-source-setup',hud:false,menu:false,...extra});
export const manifest = {
  version:3, title:'THE QUIET RELAY', seed:421002, fps:24, width:1280, height:720,
  publishedBaseline:'e731fd53', sourceLock:'515daf07589150dd3241f4ae1425cc1b093912f5',
  credit:'Rendered in-engine cinematic • scripted source inputs / staged cameras',
  capture:'Offline source 60 Hz; every output frame rendered; wall cadence measured separately',
  music:{path:'godot/audio/music/orchestral',title:'Relay / Warden',bpm:80,barSeconds:3,
    integratedLUFS:-18,truePeakDBTP:-1.5,encodeTruePeakDBTP:-2.2},
  optionalAssets:[], // No pending maps/skins admitted implicitly. Requires new reviewed manifest + hashes.
  chapters,
  shots:[
    shot('root-reveal',0,6,'terrain',{route:'interlude-canopy-link',text:'I / ROOTFALL VERGE',menu:true}),
    shot('mara',0,3,'npc',{subject:'mara',text:'MARA / THE REPEATER IS STILL BREATHING',menu:true}),
    shot('patch',0,6,'pet',{subject:'patch',text:'SOME CONNECTIONS NEED NO WORDS',menu:true}),
    shot('root-run',0,6,'traverse',{route:'critical-path',camera:'fp',hud:true,evidence:'ordinary-input-after-default-spawn',text:''}),
    shot('silt-reveal',1,6,'terrain',{route:'interlude-waterwheel-link',text:'II / SILTWAKE CROSSING',menu:true}),
    shot('ivo',1,3,'npc',{subject:'ivo',text:'IVO / WE MADE IT TO THE INTAKE',menu:true}),
    shot('silt-fire',1,6,'played-combat',{camera:'fp',hud:true,evidence:'ordinary-input-after-controlled-setup',text:'',menu:true}),
    shot('silt-ferry',1,3,'terrain',{route:'interlude-ferry-link',text:'TAKE THE OTHER PATH'}),
    shot('ember-reveal',2,6,'terrain',{route:'interlude-foundry-link',text:'III / EMBERLINE ASCENT',menu:true}),
    shot('ember-run',2,6,'traverse',{route:'interlude-condenser-a',continuation:['interlude-condenser-link','interlude-condenser-b'],camera:'fp',hud:true,evidence:'ordinary-input-after-controlled-setup',jump:true,text:''}),
    shot('robots',2,3,'combat',{camera:'external',text:'BREAK THE QUARANTINE'}),
    shot('kick',0,3,'melee',{camera:'fp',hud:true,text:''}),
    shot('danger',2,3,'artillery',{camera:'external',text:''}),
    shot('crown-reveal',3,6,'terrain',{route:'interlude-choir-link',text:'IV / CROWN ARRAY',menu:true}),
    shot('warden',3,3,'warden',{camera:'external',text:'THE LAST GUARDIAN'}),
    shot('title',3,6,'terrain',{route:'interlude-garden-link',text:'THE QUIET RELAY / FOUR CONNECTED CHAPTERS'}),
  ],
};
