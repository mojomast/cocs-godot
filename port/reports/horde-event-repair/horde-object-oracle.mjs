// Read-only observation of exact source event OBJECTS, independent of adapter
// cursor/serial arithmetic. Distinct objects with identical payloads both count.
import {isDeepStrictEqual} from 'node:util';
export function createObjectOracle() {
 const matches=new WeakMap(),records=[];
 let matchCount=0,calls=0,emptyCalls=0;
 return {
  records,
  check(match,actual) {
   calls++;
   let state=matches.get(match);
   if(!state){state={id:++matchCount,seen:new WeakSet(),last:null,ordinal:0};matches.set(match,state);}
   const lost=state.last!==null&&!match.events.includes(state.last);
   const fresh=match.events.filter(event=>!state.seen.has(event));
   const expected=fresh.map(event=>{state.seen.add(event);return{...event,sourceId:event.id,id:++state.ordinal};});
   if(match.events.length)state.last=match.events.at(-1);
   const ok=!lost&&isDeepStrictEqual(actual,expected);
   if(fresh.length||actual.length||!ok)records.push({match:state.id,sourceTime:match.time,
    observedMs:performance.now(),lost,ok,expectedFromDistinctSourceObjects:expected,actual});
   else emptyCalls++;
   return actual; // diagnostics never change the adapter's returned batch
  },
  summary() {return{matchCount,calls,emptyCalls,batches:records.length,
   sourceObjects:records.reduce((sum,r)=>sum+r.expectedFromDistinctSourceObjects.length,0),
   mismatches:records.filter(r=>!r.ok).length,passed:records.every(r=>r.ok)};},
 };
}
export function installCursorOracle(EventCursor) {
 const oracle=createObjectOracle(),original=EventCursor.prototype.take;
 EventCursor.prototype.take=function(match){return oracle.check(match,original.call(this,match));};
 return {oracle,restore(){EventCursor.prototype.take=original;}};
}
