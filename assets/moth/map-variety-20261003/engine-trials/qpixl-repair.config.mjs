// Trusted executable local config: same generation recipes, explicit flat shape.
// Invoke mothbake repair, not run; no API call is needed.
import fs from 'node:fs';
const live=JSON.parse(fs.readFileSync(new URL('./live.json',import.meta.url)));
export default {...live,jobs:live.jobs.filter(j=>j.engine==='qpixl-v1').map(j=>({...j,bake:{...j.bake,width:64,height:64}})),emitters:[{type:'json',file:'qpixl-repaired.json'}]};
