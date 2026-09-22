// Verification-only process owner. Imports production adapter bytes from the
// extracted artifact, with NO observe callback or source object instrumentation.
import {pathToFileURL} from 'node:url';
const {createAuthority}=await import(pathToFileURL(process.argv[2]).href);
const game=createAuthority();
async function close(){await game.close();console.log('HORDE_VERIFY_CLOSED');}
process.once('SIGTERM',close);process.once('SIGINT',close);
try{
 await new Promise((resolve,reject)=>{game.server.once('error',reject);game.server.listen(0,'127.0.0.1',resolve);});
 console.log('HORDE_VERIFY_READY '+JSON.stringify({port:game.server.address().port,pid:process.pid}));
}catch(error){await close();throw error;}
