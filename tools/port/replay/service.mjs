// Authenticated loopback-only presentation service, one bounded request at a time.
import {createServer} from 'node:http';
import {writeFileSync} from 'node:fs';
import {LocalReplay, LIMIT} from './adapter.mjs';
const [root,ready,token]=process.argv.slice(2);
if(!root||!ready||!/^[a-f0-9]{64}$/.test(token??'')) throw Error('Expected local library, ready file and random capability');
const replay=new LocalReplay(root);
let last=Date.now();
const server=createServer((req,res)=>{
  if(req.method!=='POST'||req.url!=='/replay'||req.headers.authorization!==`Bearer ${token}`||req.headers.origin) {res.writeHead(403);res.end();return;}
  let size=0;const chunks=[];
  req.on('data',chunk=>{size+=chunk.length;if(size>LIMIT.bytes+1024){req.destroy();return;}chunks.push(chunk);});
  req.on('end',()=>{
    last=Date.now();
    try {const result=replay.dispatch(JSON.parse(Buffer.concat(chunks)));res.writeHead(200,{'Content-Type':'application/json'});res.end(JSON.stringify({ok:true,...result}));}
    catch(e){res.writeHead(200,{'Content-Type':'application/json'});res.end(JSON.stringify({ok:false,error:String(e.message).slice(0,400)}));}
  });
});
server.requestTimeout=5000;server.headersTimeout=5000;
server.listen(0,'127.0.0.1',()=>writeFileSync(ready,JSON.stringify({port:server.address().port}),{flag:'wx',mode:0o600}));
setInterval(()=>{if(Date.now()-last>30000){server.close();process.exit(0);}},5000).unref();
process.on('SIGTERM',()=>{server.close();process.exit(0);});
