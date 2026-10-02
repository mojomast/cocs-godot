// Refresh the effects-only source contract from the content owner's real roster.
// This writes no content-owned files and never runs engine/toolchain imports.
import {readFile,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import path from 'node:path';
import {root} from './build.mjs';
const input = process.argv[2];
if (!input) throw Error('Usage: node tools/fighting/effects/sync_content.mjs path/to/roster.json');
const bytes = await readFile(input), roster = JSON.parse(bytes);
const operators = {};
for (const operator of roster.operators) {
  operators[operator.id] = {};
  for (const [key,move] of Object.entries(operator.moves)) {
    const fields = {};
    for (const field of ['effect','kind','level','startup','active','recovery','movement','throw','counter','stance']) {
      if (field in move) fields[field] = move[field];
    }
    if (fields.effect !== `${operator.id}:${key}`) throw Error(`Unexpected authoritative effect ID ${fields.effect}`);
    operators[operator.id][key] = fields;
  }
}
await writeFile(path.join(root,'tools/fighting/effects/content_contract.json'),JSON.stringify({version:1,
  source_commits:['827d24a8','79d98652','bcb1effe','242d5741','672c81a7'],roster_sha256:createHash('sha256').update(bytes).digest('hex'),operators},null,2)+'\n');
console.log('Refreshed effects-only contract for '+Object.values(operators).reduce((n,o)=>n+Object.keys(o).length,0)+' actual moves');
