import {openSync,closeSync,readFileSync,writeFileSync,mkdirSync,statSync,fstatSync,unlinkSync,existsSync,chmodSync,renameSync} from 'node:fs';
import {join,dirname,isAbsolute,resolve} from 'node:path';
import {homedir} from 'node:os';
import {createHash} from 'node:crypto';

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
  return {root:location,progressionPath:resolve(selected),historyPath:join(location,'history.json'),legacyCredentialsPath:join(location,'identities.json')};
}

function inspect(file,max,kind){
 if(!existsSync(file))return null;
 const stat=statSync(file);
 if(!stat.isFile()||stat.size>max||stat.size===0)throw Error(`Career ${kind} is invalid; repair the existing file before launching`);
 let value;
 try{value=JSON.parse(readFileSync(file,'utf8'));}catch{throw Error(`Career ${kind} is malformed; repair the existing file before launching`);}
 if(value===null)throw Error(`Career ${kind} is invalid; repair the existing file before launching`);
 return value;
}

function privateDirectory(path){mkdirSync(path,{recursive:true,mode:0o700});if(process.platform!=='win32')chmodSync(path,0o700);}
function privateFile(path){if(process.platform!=='win32')chmodSync(path,0o600);}
function validIdentities(value,legacy,scope){
 if(value?.version!==1||!value.scopes||typeof value.scopes!=='object'||Array.isArray(value.scopes))throw Error('Career credential store has an unsupported schema');
 const entries=Object.entries(value.scopes);
 if(entries.length>(legacy?32:1)||entries.some(([key,pair])=>key.length>2048||!pair||typeof pair!=='object'||!(/^[A-Za-z0-9-]{8,64}$/.test(pair.playerId??''))||!(/^[A-Za-z0-9_-]{16,128}$/.test(pair.progressToken??''))||(!legacy&&key!==scope)))throw Error('Career credential store contains invalid identities');
 return value;
}

// Exclusive for the entire authority lifetime: ProgressionStore holds a snapshot
// in memory and cannot merge another instance's writes. No expiry while a PID
// exists; crashed processes leave a reclaimable PID lease.
export function acquireCareer(plan,env=process.env,options={}){
 const paths=careerPaths(env,options);
 const owned=!plan.nativeOnly&&!plan.endpoint&&!plan.nativeArena&&!plan.identityZone&&plan.experience!=='horde';
  const scope=owned?'owned:source-v3':plan.endpoint?`external:${new URL(plan.endpoint).href}`:null;
  if(!scope)return {env:{COCS_CAREER_CREDENTIALS_PATH:'',COCS_CAREER_SCOPE:'',COCS_CAREER_ENDPOINT:''},progressionPath:null,historyPath:null,release(){}};
  privateDirectory(paths.root);
  const identityDir=join(paths.root,'identities');
  privateDirectory(identityDir);
  // Hashing avoids leaking an external server's URL through filesystem names.
  // The source-backed owned session leases only its own credential/store scope.
  const credentialsPath=join(identityDir,`${createHash('sha256').update(scope).digest('hex')}.json`);
  const lease=`${credentialsPath}.lease`;
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
    // MatchHistory owns the contents and the 50-match retention policy. Check
    // its loaded shape before construction so corruption cannot silently become
    // an empty history and overwrite the existing record on the next match.
    const history=inspect(paths.historyPath,MAX_STORE,'history store');
    if(history!==null){
     if(!Array.isArray(history)||history.some(match=>!match||typeof match!=='object'||Array.isArray(match)||!Array.isArray(match.players)||match.players.some(player=>!player||typeof player!=='object'||Array.isArray(player))))throw Error('Career history store has an unsupported schema');
     privateFile(paths.historyPath);
    }
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
   // Legacy shared credentials are read-only migration input. Validate even if
   // the per-scope file exists: malformed legacy data must not pass unnoticed.
   const legacy=inspect(paths.legacyCredentialsPath,MAX_CREDENTIALS,'legacy credential store');
   if(legacy!==null)validIdentities(legacy,true,scope);
   const current=inspect(credentialsPath,MAX_CREDENTIALS,'credential store');
   if(current!==null)validIdentities(current,false,scope);
   else{
    const pair=legacy?.scopes[scope];
    const temp=`${credentialsPath}.${process.pid}.tmp`;
    try{
     writeFileSync(temp,JSON.stringify({version:1,scopes:pair?{[scope]:pair}:{}}),{flag:'wx',mode:0o600});
     renameSync(temp,credentialsPath);
    }catch(error){if(existsSync(temp))unlinkSync(temp);throw error;}
   }
   privateFile(credentialsPath);
   if(owned&&process.platform!=='win32')previousMask=process.umask(0o077);
   return {env:{COCS_CAREER_CREDENTIALS_PATH:credentialsPath,COCS_CAREER_SCOPE:scope,COCS_CAREER_ENDPOINT:''},progressionPath:owned?paths.progressionPath:null,historyPath:owned?paths.historyPath:null,release};
 }catch(error){release();throw error;}
}
