import {createServer} from 'vite';
import {chromium} from 'playwright';
import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {verifySource} from './semantic.mjs';
const lock=JSON.parse(readFileSync('port/contracts/source-lock.json'));verifySource(lock);
const id=process.argv[2];if(id&&!lock.map_ids.includes(id))throw Error('Map not allowlisted');
const server=await createServer({configFile:false,root:process.cwd(),server:{host:'127.0.0.1',port:0},optimizeDeps:{noDiscovery:true}});
await server.listen();
let browser;
try{
 browser=await chromium.launch({headless:true,args:['--enable-unsafe-swiftshader'],...(process.env.CHROMIUM_PATH?{executablePath:process.env.CHROMIUM_PATH}:{})});
 const page=await browser.newPage();const messages=[];
 page.on('pageerror',e=>messages.push(String(e)));page.on('console',m=>{if(['warning','error'].includes(m.type()))messages.push(m.text());});
 await page.goto(`http://127.0.0.1:${server.httpServer.address().port}/tools/godot-export/harness.html`);
 await page.waitForFunction(()=>window.ready,{},{timeout:60000});
 const result=await page.evaluate(id=>id?window.exportMap(id):window.exportProbe(),id);
 const output=id?`godot/content/probes/${id}`:'godot/content/probes/axis-weapon';mkdirSync(output,{recursive:true});
 const bytes=Buffer.from(result.bytes);writeFileSync(`${output}/world.glb`,bytes);
 const report={source_commit:lock.source_commit,...result.report,bytes:bytes.length,sha256:createHash('sha256').update(bytes).digest('hex'),messages};
 writeFileSync(`port/reports/${id??'axis-weapon'}-glb.json`,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({...report,nodes:report.nodes.length},null,2));
}finally{await browser?.close();await server.close();}
