// Source-only: execute the production layout arithmetic with supplied logical
// viewport / wrapped minima. Font shaping and Control layout remain native gates.
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {runInNewContext} from 'node:vm';

const source=readFileSync(new URL('../../combined_arms/hud.gd',import.meta.url),'utf8');
const body=source.split('func layout() -> void:\n')[1].split('\nfunc ')[0];
const constants=Object.fromEntries([...source.matchAll(/^const (FOOTER_SAFE|HUD_MARGIN|HUD_GAP) := ([\d.]+)$/gm)].map(([,key,value])=>[key,Number(value)]));
// This deliberately small translator rejects additions outside this arithmetic
// subset rather than maintaining a second implementation of the layout policy.
const code=body.split('\n').filter(line=>line.trim()&&!line.trim().startsWith('#')).map(line=>{
  line=line.trim().replace(/^var (\w+) := /,'let $1 = ');
  if(line.includes(' if '))line=line.replace(/^(let \w+ = )(.+) if (.+) else (.+)$/,'$1($3 ? $2 : $4)');
  assert.ok(!line.includes(' := ')&&!line.includes(' if '),'unsupported layout syntax');
  return line+';';
}).join('\n');
function layout(width,height,top,bottom,hint=40){
  const region=()=>({position:{x:0,y:0},size:{x:0,y:0}});
  const context={...constants,get_viewport:()=>({get_visible_rect:()=>({size:{x:width,y:height}})}),
    top_rows:{get_combined_minimum_size:()=>({y:top})},bottom_rows:{get_combined_minimum_size:()=>({y:bottom})},
    top_scroll:region(),bottom_scroll:region(),scroll_hint:{...region(),get_combined_minimum_size:()=>({y:hint})},
    Vector2:(x,y)=>({x,y}),minf:Math.min,maxf:Math.max};
  runInNewContext(code,context);
  return context;
}
function bounded(c,width,height){
  const a=c.top_scroll,b=c.bottom_scroll;
  for(const r of [a,b]){
    assert.ok(r.position.y>=0&&r.size.y>=0);
    assert.ok(r.position.x+r.size.x<=width);
    assert.ok(r.position.y+r.size.y<=height-constants.FOOTER_SAFE+1e-8);
  }
  assert.ok(a.position.y+a.size.y+constants.HUD_GAP<=b.position.y+1e-8);
  if(c.scroll_hint.visible)assert.ok(c.scroll_hint.position.y+c.scroll_hint.get_combined_minimum_size().y<=height-constants.FOOTER_SAFE+1e-8);
}

test('760x520 UI150: wrapped driver rows get their full height above F12',()=>{
  const c=layout(760/1.5,520/1.5,92,142);
  bounded(c,760/1.5,520/1.5);
  assert.equal(c.top_scroll.size.y,92);
  assert.equal(c.bottom_scroll.size.y,142);
  assert.equal(c.scroll_hint.visible,false);
  assert.ok(c.bottom_scroll.position.y<520/1.5*.66,'regression: no fixed lower 34% band');
});
test('wide viewport keeps measured lower controls bottom-anchored',()=>{
  const c=layout(1280,800,86,104);
  bounded(c,1280,800);
  assert.equal(c.bottom_scroll.position.y+c.bottom_scroll.size.y,800-constants.FOOTER_SAFE);
  assert.equal(c.scroll_hint.visible,false);
});
test('long objective/status gives both regions bounded keyboard-scroll space',()=>{
  const c=layout(506,346,420,142);
  bounded(c,506,346);
  assert.equal(c.scroll_hint.visible,true);
  assert.ok(c.top_scroll.size.y<420&&c.top_scroll.size.y>0);
  assert.ok(c.bottom_scroll.size.y>0);
});
test('long remapped controls use spare upper capacity without losing footer',()=>{
  const c=layout(506,346,60,400);
  bounded(c,506,346);
  assert.equal(c.top_scroll.size.y,60);
  assert.ok(c.bottom_scroll.size.y>c.top_scroll.size.y);
  assert.equal(c.scroll_hint.visible,true);
});
test('resize/accessibility boundaries preserve nonoverlap with wrapped minima',()=>{
  for(const [w,h] of [[640,480],[760,520],[1280,800],[1920,1080]])
    for(const scale of [.75,1,1.25,1.5])
      for(const [top,bottom] of [[80,100],[92,142],[200,300],[400,500]])bounded(layout(w/scale,h/scale,top,bottom),w/scale,h/scale);
});
test('production retains controls, user scale, shared scroll navigation and reachable focus',()=>{
  for(const text of ['WASD move','LMB fire','E mount / exit','Enter capture controls','Esc release','ZONE CONTROL','Snapshots stale'])assert.ok(source.includes(text),text);
  assert.match(source,/scroll_keys\.gd"\)\.bind\(scroll\)/);
  assert.match(source,/top_scroll\.focus_next = top_scroll\.get_path_to\(bottom_scroll\)/);
  assert.match(source,/bottom_scroll\.focus_next = bottom_scroll\.get_path_to\(top_scroll\)/);
  assert.match(source,/Control\.FOCUS_ALL if released else Control\.FOCUS_NONE/);
  assert.match(source,/bottom_scroll\.scroll_vertical = 0/);
  assert.doesNotMatch(body,/font_size|content_scale|ui_scale/);
  const settings=readFileSync(new URL('../../ui/local_settings.gd',import.meta.url),'utf8');
  const footerTop=Number(settings.match(/hint\.offset_top = (-\d+)/)[1]);
  assert.ok(constants.FOOTER_SAFE>-footerTop,'safe area covers actual global F12 hint');
});
