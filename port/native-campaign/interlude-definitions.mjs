// Authored action blocks. Local coordinates are metres along/across the road;
// the compiler and authority resolve them from the same reviewed route recipe.
export const INTERLUDE_DEFINITIONS = Object.freeze({
  'rootfall-verge':[
    {id:'nursery',title:'Mara’s seed nursery',family:'link',step:1,segment:2,theme:'nursery',a:[-9,6],b:[9,12],reward:'armor',
      actions:['Connect nursery battery','Start the irrigation rotor'],hint:'Follow the copper cable to the dry nursery. Two connections bring it back.',
      result:'Mara: The seed beds are drinking again. Take the nursery’s spare plating. +35 armor.'},
    {id:'canopy',title:'Ivo’s canopy receiver',family:'align',step:3,segment:8,theme:'receiver',a:[-8,7],b:[10,13],reward:'ammo',
      actions:['Look at the gold receiver and lock signal','Rescue frequency'],hint:'Stand at the sighting dish; look toward the gold receiver and press E.',
      result:'Ivo: The lost crew’s rescue frequency. Take their scattergun and reserve ammunition.'}],
  'siltwake-crossing':[
    {id:'waterwheel',title:'The sleeping waterwheel',family:'link',step:2,segment:6,theme:'waterwheel',a:[-10,6],b:[10,12],reward:'ammo',
      actions:['Prime the auxiliary pump','Engage the waterwheel'],hint:'The small pump feeds the great wheel. Follow its pipe and restart both.',
      result:'Mara: The relief wheel is turning. A loaded scattergun and reserve ammo for you.'},
    {id:'ferry',title:'The abandoned ferry berth',family:'choice',step:3,segment:10,theme:'ferry',a:[-8,10],b:[8,10],reward:'choice',
      actions:['Salvage plating (+35 armor)','Take scattergun + ammunition'],hint:'One ferry battery remains. Power the plating press OR the ammunition rack.',
      result:'Ivo: The ferry carried our evacuation supplies. Good to see them put to use.'}],
  'emberline-ascent':[
    {id:'condenser',title:'The cold condenser',family:'link',step:1,segment:4,theme:'condenser',a:[-10,6],b:[10,12],reward:'armor',
      actions:['Couple the cooling return','Vent the condenser'],hint:'Trace the blue return pipe around the condenser; vent it at the far valve.',
      result:'Mara: Cold exhaust. Patch can cross behind us now. Spare thermal plates: +35 armor.'},
    {id:'foundry',title:'Ivo’s field forge',family:'choice',step:3,segment:12,theme:'foundry',a:[-9,10],b:[9,10],reward:'choice',
      actions:['Forge plating (+35 armor)','Forge scattergun + ammunition'],hint:'One charged ingot. Choose the shield press or the cartridge die.',
      result:'Ivo: One last batch from the old forge. Make it count at the Crown.'}],
  'crown-array':[
    {id:'choir',title:'The silent signal choir',family:'align',step:1,segment:4,theme:'choir',a:[-9,7],b:[9,13],reward:'ammo',
      actions:['Look at the gold choir dish and lock signal','Corridor receiver'],hint:'At the sighting dish, face the gold receiver. The silent choir can sing again.',
      result:'ECHO: A civilian band. The choir answers. Scattergun and reserve ammo released.'},
    {id:'garden',title:'Patch’s beacon garden',family:'link',step:2,segment:7,theme:'garden',a:[-9,6],b:[9,12],reward:'armor',
      actions:['Connect the garden cell','Illuminate the homeward beacons'],hint:'Light the two ends of the garden cable. Leave a path home for Mara, Ivo and Patch.',
      result:'Mara: We can see the way home. Take the last repair plates. +35 armor.'}]
});

export function interludeDefinitions(data) {
  return INTERLUDE_DEFINITIONS[data.id].map(def=>{
    const route=suffix=>data.routes.find(r=>r.id===`interlude-${def.id}-${suffix}`);
    if(!route('a')||!route('b'))throw new Error(`Missing authored interlude routes: ${def.id}`);
    const block=data.arena.blocks.find(b=>b.id===`interlude-${def.id}-machine-base`)??
      data.arena.blocks.filter(b=>b.id.startsWith(`interlude-${def.id}-`)).sort((a,b)=>b.h-a.h)[0];
    return {...def,a:route('a').points.at(-1),b:route('b').points.at(-1),machine:{x:block.x,y:block.h+1,z:block.z},
      cable:route('link').points,entry:route('a').points[0]};
  });
}
