// Parent-reviewed a5c26f25 feature entry points. Package dependencies only;
// original production acceptance is not native acceptance of these features.
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
export const FEATURE_ROOTS=[
 'godot/ui/main_menu.gd','godot/ui/local_settings.gd',
 'godot/campaign/demo.gd','godot/fighting/main.gd',
 'godot/combined_arms/demo.gd','godot/sports/demo.gd',
 'godot/multiplayer_worlds/sports_demo.gd','godot/world/session.gd',
];
export const FEATURE_REVIEW_SCOPE='supporting package dependency reconciliation only; native feature checks pending';
export const FEATURE_RUNTIME_ADVANCES={
 robots:{'godot/campaign/demo.gd':{before:'7fab4d8128cb0b0343bcd64f9c9f776c01cf14cd38cd511da8db5c4192ecc34e',after:'cd90b6be02614af02f01b145ffbb9ee419b60a9612e3520029963a60b6414a43'}},
 vehicles:{'godot/combined_arms/demo.gd':{before:'5d71ec6912052cdfb4d35a69b333efb6dfba981615ef76948186da0f4feec9b0',after:'80a773cc40f0497e0ed41f5d0da89e2476b2b0fdfc022a165e71941bf873e78f'}},
};
export const ROBOT_SHARED_RUNTIME_ADVANCES={
 'godot/source_operators/motion_math.gd':{before:'ef5133895e42a7b5e60e80bfc5e09da021566ab1e40ae12eee523d4c46d8b633',after:'967f5f5167f4eac4b7b24212be058c149bb751c45450c1c2628cb42b24a8d069',legacyFunctions:{spring:'bcc4a396fe2eef0ca967a127994f38c62b5658db24cee03213e068020589d1a8',smooth:'f3d7d36d34f55f8ee1b64aeb3d0eb5209e1fbb8c84acbf0ba103ea1d243cadad',contact:'a14208e774a1d26c61b641ec66db7417baebff7aff437a9ffe633aa61f4c7979',two_link:'9e6c18734c96f5af825e38a2a8e0552b92eaa261471966a7fc0f78193bc5beab'}},
 'godot/source_operators/ground_contact.gd':{before:'566f0b43f3430593eff3e6a35a9841a4ed3a67e00b202c3153f5fab75fb5b4fd',after:'f3aa53909b7fabbcca396d19b7a1704cdf9e0279f368afdd8722fc8a38817bd9',legacyFunctions:{offset:'ce974e01c0e0e727ac9e65de0ad629c0431753bd048c6e96767f962f2b2ab5d7'}},
};
const hash=b=>createHash('sha256').update(b).digest('hex');
// Textual executable function identity, not a grammar or runtime proof. Ignore
// blank lines/comment-only lines; preserve executable indentation and tokens.
export function legacyFunctionHashes(source){
 const result={};let name=null,body=[];
 for(const line of [...source.split(/\r?\n/),'func END():']){
  const match=/^(?:static )?func (\w+)\(/.exec(line);
  if(match){if(name)result[name]=hash(body.join('\n')+'\n');name=match[1];body=[line.trim()];}
  else if(name&&/^[\t ]/.test(line)&&line.trim()&&!line.trimStart().startsWith('#'))body.push(line.trimEnd());
 }
 return result;
}
export function robotSupportingHash(path,original,receipt,read){
 const change=receipt.featureAdvance?.sharedRuntimeChanged?.[path];
 if(!change)return original;
 assert.deepEqual(change,ROBOT_SHARED_RUNTIME_ADVANCES[path],'Unreviewed robot supporting API advance');
 assert.equal(change.before,original,'Original D contract source remains required');
 const bytes=read(path);assert.equal(hash(bytes),change.after,'Reviewed operator helper identity');
 const functions=legacyFunctionHashes(bytes.toString());
 for(const [name,sha]of Object.entries(change.legacyFunctions))assert.equal(functions[name],sha,'Legacy robot function drift: '+name);
 return change.after;
}
export function verifyFeatureAdvance(receipt) {
 const record=receipt.featureAdvance;
 assert.ok(record,'Explicit source-only feature reconciliation required');
 assert.equal(record.review.foundation,'a5c26f25');
 assert.equal(record.review.scope,FEATURE_REVIEW_SCOPE);
 assert.equal(record.review.nativeFeatureChecks,'pending');
 assert.deepEqual(record.runtimeChanged,FEATURE_RUNTIME_ADVANCES[receipt.unit]??{},'Unreviewed feature runtime advance');
 assert.deepEqual(record.sharedRuntimeChanged,receipt.unit==='robots'?ROBOT_SHARED_RUNTIME_ADVANCES:{},'Unreviewed shared runtime advance');
 for(const [path,change]of Object.entries(record.runtimeChanged))assert.equal(receipt.runtimeHooks[path],change.after,'Feature runtime current identity');
}
