import test from 'node:test';
import assert from 'node:assert/strict';
import * as T from 'three';
import {WeaponFeedback} from './feedback.mjs';
import {AdsController} from './weapon-ads.mjs';

const player={id:1,weapon:0,health:100,grounded:true,sliding:true,vx:8,vz:0};
test('slide pose is bounded, elapsed-time damped, actor-neutral and cleared at visibility boundaries',()=>{
 const poses=[];
 for(const hz of [30,60,120,144]){
  const f=new WeaponFeedback(),copy=structuredClone(player);let pose;
  for(let i=0;i<hz;i++)pose=f.update(player,1/hz);
  assert.deepEqual(player,copy);assert.ok(pose.slide.roll>0&&pose.slide.roll<=.08);
  assert.ok(pose.slide.x<=.018&&pose.slide.y>=-.025);poses.push(pose.slide);
  f.update(player,1/hz,true);assert.equal(f.slide,0);
  for(const boundary of [{health:0},{vehicleId:1},{dead:true},{spectating:true}]){
   f.update(player,.1);f.update({...player,...boundary},.1);assert.equal(f.slide,0);
  }
  f.update(player,.1);f.update(player,.1,false,false);assert.equal(f.slide,0);
 }
 for(const pose of poses)assert.ok(Math.abs(pose.roll-poses[0].roll)<1e-12);
});
test('settled ADS completely removes slide translation and cant without changing FOV or reticle',()=>{
 const f=new WeaponFeedback(),pose=f.update(player,.1),ads=new AdsController();
 ads.update(1,{weapon:0,aiming:true,reduced:true});
 const before=structuredClone({fov:ads.state.fov,reticle:ads.state.reticle});
 const p=new T.Vector3(),q=new T.Quaternion(),neutralP=new T.Vector3(),neutralQ=new T.Quaternion();
 ads.compose(p,q,pose,f.channels);ads.compose(neutralP,neutralQ,{...pose,slide:null},f.channels);
 assert.ok(p.distanceTo(neutralP)<1e-12);assert.ok(q.angleTo(neutralQ)<1e-7);
 assert.deepEqual({fov:ads.state.fov,reticle:ads.state.reticle},before);
 ads.reset();ads.compose(p,q,pose,f.channels);ads.compose(neutralP,neutralQ,{...pose,slide:null},f.channels);
 assert.ok(p.distanceTo(neutralP)>0);assert.ok(q.angleTo(neutralQ)>0);
});
