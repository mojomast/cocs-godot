// Capture genuine browser source output on a private ephemeral port.
import {createServer} from 'node:http';
import {readFile,mkdir,writeFile} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import {resolve,extname,sep} from 'node:path';
import {chromium} from 'playwright';
const root=fileURLToPath(new URL('../../',import.meta.url)),out=resolve(root,'port/native-source-operators/evidence');
await mkdir(out,{recursive:true});
const server=createServer(async(req,res)=>{
  const path=resolve(root,'.'+new URL(req.url,'http://localhost').pathname);
  if(!path.startsWith(root.endsWith(sep)?root:root+sep)){res.writeHead(403).end();return;}
  try{res.setHeader('content-type',({'.mjs':'text/javascript','.js':'text/javascript','.html':'text/html','.json':'application/json'})[extname(path)]||'application/octet-stream');res.end(await readFile(path));}catch{res.writeHead(404).end();}
});
await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
const browser=await chromium.launch({headless:true,...(process.env.CHROMIUM_PATH?{executablePath:process.env.CHROMIUM_PATH}:{}),args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
try{
  const page=await browser.newPage();const errors=[];page.on('pageerror',e=>{errors.push(String(e));console.error(e);});
  page.on('response',res=>{if(res.status()>=400)console.error(res.status(),res.url());});
  page.on('console',message=>{if(message.type()==='error')console.error(message.text());});
  await page.goto(`http://127.0.0.1:${server.address().port}/tools/godot-operators/reference.html`);
  await page.waitForFunction(()=>window.ready);
  async function capture(name,options){const data=await page.evaluate(o=>window.capture(o),options);await writeFile(resolve(out,name),Buffer.from(data.split(',')[1],'base64'));}
  for(const [width,height] of [[1280,800],[1920,1080]])for(const id of ['claude','grok','meta'])for(const view of ['front','side','back','10m','25m']){
    const distance=['front','side','back'].includes(view)?3:view==='10m'?10:25,angle=view==='side'?Math.PI/2:view==='back'?Math.PI:0;
    await capture(`source-${id}-${view}-${width}.png`,{id,width,height,distance,angle});
  }
  for(let frame=0;frame<12;frame++)await capture(`source-walk-${String(frame).padStart(2,'0')}.png`,{id:'claude',width:512,height:512,distance:2.7,angle:.32,state:{phase:frame*Math.PI*2/12,speedNorm:.65,forward:1,time:.4}});
  if(errors.length)throw new Error(errors.join('\n'));
  console.log('Captured genuine source references, source files unchanged.');
}finally{await browser.close();await new Promise(resolve=>server.close(resolve));}
