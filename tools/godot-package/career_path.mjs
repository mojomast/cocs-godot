import {openSync,closeSync,readFileSync,writeFileSync,mkdirSync,statSync,fstatSync,unlinkSync,existsSync,chmodSync} from 'node:fs';
import {join,dirname,isAbsolute,resolve} from 'node:path';
import {homedir} from 'node:os';

const MAX_STORE=16*1024*1024;
const MAX_CREDENTIALS=256*1024;
export function careerPaths(env=process.env,{developmentRoot,home=homedir(),platform=process.platform}={}){
 if(env.COCS_CAREER_ROOT&&env.COCS_CAREER_PATH)throw Error('Choose either COCS_CAREER_ROOT or COCS_CAREER_PATH');
 const config=platform==='win32'?(env.APPDATA&&isAbsolute(env.APPDATA)?env.APPDATA:join(home,'AppData','Roaming')):platform==='darwin'?join(home,'Library','Application Support'):(env.XDG_CONFIG_HOME&&isAbsolute(env.XDG_CONFIG_HOME)?env.XDG_CONFIG_HOME:join(home,'.config'));
 const root=env.COCS_CAREER_ROOT??(developmentRoot?join(developmentRoot,'.port-runtime','career'):join(config,'cocs-native','career'));
 if(!isAbsolute(root))throw Error('Career root must be absolute');
 const selected=env.COCS_CAREER_PATH??join(root,'progression.json');
 if(!isAbsolute(selected))throw Error('Career path must be absolute');
 const location=env.COCS_CAREER_PATH?dirname(resolve(selected)):resolve(root);
 return {root:location,progressionPath:resolve(selected),credentialsPath:join(location,'identities.json'),lockPath:`${resolve(selected)}.lease`};
}

function inspect(file,max,kind){
 if(!existsSync(file))return null;
 const stat=statSync(file);
 if(!stat.isFile()||stat.size>max||stat.size===0)throw Error(`Career ${kind} is invalid; repair the existing file before launching`);
 let value;
 try{value=JSON.parse(readFileSync(file,'utf8'));}catch{throw Error(`Career ${kind} is malformed; repair the existing file before launching`);}
 return value;
}

function privateDirectory(path){mkdirSync(path,{recursive:true,mode:0o700});if(process.platform!=='win32')chmodSync(path,0o700);}
function privateFile(path){if(process.platform!=='win32')chmodSync(path,0o600);}

// Exclusive for the entire authority lifetime: ProgressionStore holds a snapshot
// in memory and cannot merge another instance's writes. No expiry while a PID
// exists; crashed processes leave a reclaimable PID lease.
export function acquireCareer(plan,env=process.env,options={}){
 const paths=careerPaths(env,options);
 const owned=!plan.nativeOnly&&!plan.endpoint&&!plan.nativeArena&&!plan.identityZone&&plan.experience!=='horde';
 const scope=owned?'owned:source-v3':plan.endpoint?`external:${new URL(plan.endpoint).href}`:null;
 if(!scope)return {env:{COCS_CAREER_CREDENTIALS_PATH:'',COCS_CAREER_SCOPE:'',COCS_CAREER_ENDPOINT:''},progressionPath:null,release(){}};
 privateDirectory(paths.root);
 // A shared credential file must not be edited concurrently by separate routes.
 const lease=`${paths.credentialsPath}.lease`;
 let fd;
 try{fd=openSync(lease,'wx',0o600);}catch(error){
  if(error.code!=='EEXIST')throw error;
  // A separate exclusive reclaimer gate keeps two stale-lease readers from
  // unlinking each other's newly acquired live lease.
  const gate=`${lease}.reclaim`;
  let claim;
  try{claim=openSync(gate,'wx',0o600);}catch{throw Error('Career store is busy (lease reclamation in progress)');}
  try{
   let pid;
   try{pid=Number(readFileSync(lease,'utf8').trim());}catch{}
   if(!Number.isSafeInteger(pid)||pid<1)throw Error('Career store is busy (unreadable lease)');
   try{process.kill(pid,0);throw Error('Career store is busy (another session is active)');}
   catch(probe){if(probe.code!=='ESRCH')throw probe;}
   unlinkSync(lease);
   fd=openSync(lease,'wx',0o600);
  }finally{unlinkSync(gate);closeSync(claim);}
 }
 let released=false,previousMask;
 const release=()=>{if(released)return;released=true;if(previousMask!==undefined)process.umask(previousMask);try{if(statSync(lease).ino===fstatSync(fd).ino)unlinkSync(lease);}catch(error){if(error.code!=='ENOENT')throw error;}finally{closeSync(fd);}};
 try{
  writeFileSync(fd,String(process.pid));privateFile(lease);
  if(owned){
   privateDirectory(dirname(paths.progressionPath));
   const store=inspect(paths.progressionPath,MAX_STORE,'progression store');
   if(store!==null){if(!(Array.isArray(store)||store&&typeof store==='object'&&Array.isArray(store.players)&&store.version===2))throw Error('Career progression store has an unsupported schema');
    for(const entry of Array.isArray(store)?store:store.players){
     if(!entry||typeof entry!=='object'||typeof entry.id!=='string'||!/^[A-Za-z0-9-]{8,64}$/.test(entry.id))throw Error('Career progression store contains invalid players');
     if(entry.ownerToken!==undefined&&!/^[A-Za-z0-9_-]{16,128}$/.test(entry.ownerToken))throw Error('Career progression store contains invalid owner credentials');
     for(const field of ['xp','matches','wins','kills'])if(entry[field]!==undefined&&(!Number.isSafeInteger(entry[field])||entry[field]<0))throw Error('Career progression store contains invalid progress');
     for(const field of ['gear','attachments','unlocks','byMode'])if(entry[field]!==undefined&&(!entry[field]||typeof entry[field]!=='object'||Array.isArray(entry[field])))throw Error('Career progression store contains invalid gear or unlocks');
    }
    privateFile(paths.progressionPath);
   }
  }
  const identities=inspect(paths.credentialsPath,MAX_CREDENTIALS,'credential store');
  if(identities===null)writeFileSync(paths.credentialsPath,JSON.stringify({version:1,scopes:{}}),{flag:'wx',mode:0o600});
  else if(identities.version!==1||!identities.scopes||typeof identities.scopes!=='object'||Array.isArray(identities.scopes))throw Error('Career credential store has an unsupported schema');
  if(identities!==null){
   const entries=Object.entries(identities.scopes);
   if(entries.length>32||entries.some(([key,pair])=>key.length>2048||!pair||typeof pair!=='object'||!(/^[A-Za-z0-9-]{8,64}$/.test(pair.playerId??''))||!(/^[A-Za-z0-9_-]{16,128}$/.test(pair.progressToken??''))))throw Error('Career credential store contains invalid identities');
  }
  privateFile(paths.credentialsPath);
  if(owned&&process.platform!=='win32')previousMask=process.umask(0o077);
  return {env:{COCS_CAREER_CREDENTIALS_PATH:paths.credentialsPath,COCS_CAREER_SCOPE:scope,COCS_CAREER_ENDPOINT:''},progressionPath:owned?paths.progressionPath:null,release};
 }catch(error){release();throw error;}
}
