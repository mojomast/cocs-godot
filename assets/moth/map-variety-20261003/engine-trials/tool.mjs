import fs from 'node:fs';
import {execFileSync} from 'node:child_process';
import {pathToFileURL} from 'node:url';
export const pin=JSON.parse(fs.readFileSync(new URL('./tool-pin.json',import.meta.url)));
const root=process.env.MOTHBAKE_IMAGE_ROOT;
if(!root)throw new Error('Set MOTHBAKE_IMAGE_ROOT to the exact image-adapter revision');
if(execFileSync('git',['-C',root,'rev-parse','HEAD'],{encoding:'utf8'}).trim()!==pin.commit)throw new Error('Image-adapter revision mismatch');
execFileSync('git',['-C',root,'diff','--quiet','HEAD','--','src']);
export const loadTool=relative=>import(pathToFileURL(`${root}/src/${relative}`).href);
