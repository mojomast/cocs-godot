// Input expansion only; no recognition, simulation, collision or combat rules.
export function expandTrace(combo,facing=1){
 if(facing!==1&&facing!==-1)throw new Error('facing must be -1 or +1');
 const samples=[...combo.setup_inputs,...combo.inputs].sort((a,b)=>a.tick-b.tick);
 const result=[],errors=[];
 let previousHeld=0,end=0;
 for(const sample of samples){
  if(sample.tick<end)errors.push('trace samples overlap');
  end=sample.tick+(sample.duration??1);
 }
 if(errors.length)throw new Error(errors.join('; '));
 const ticks=end+1; // Include explicit release after the final sparse sample.
 for(let tick=0;tick<ticks;tick++){
  const sample=samples.find(s=>tick>=s.tick&&tick<s.tick+(s.duration??1));
  const held=sample?.held??0;
  const pressed=held&~previousHeld;
  if(sample?.tick===tick&&sample.pressed!==pressed)errors.push(`tick ${tick}: pressed hint differs from held rising edge`);
  result.push({axis_x:(sample?.axis_x??0)*facing,axis_y:sample?.axis_y??0,held,pressed});
  previousHeld=held;
 }
 if(errors.length)throw new Error(errors.join('; '));
 return result;
}
