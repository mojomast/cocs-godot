// Source input samples, in order: one sample per source step. Only held fields
// survive a step without a new sample (game/input.mjs + app/page.tsx local loop).
export const INPUT_LIMIT = 16;
export const INPUT_TTL_MS = 250;
const PULSES = ['power', 'interact', 'reload', 'melee', 'grenade', 'weapon'];
export class InputBuffer {
 constructor() { this.reset(); }
 reset() {
  this.queue = []; this.held = {}; this.lastAt = null;
  this.received = 0; this.applied = 0; this.cancelledThrough = 0;
 }
 cancel() {
  this.cancelledThrough = this.received;
  this.queue = []; this.held = {}; this.lastAt = null;
 }
 receive(seq, input, now, cancel = false) {
  if (!Number.isSafeInteger(seq) || seq <= this.received) return false;
  if (cancel) this.cancel();
  if (this.queue.length >= INPUT_LIMIT) throw Error('Input queue limit');
  this.received = seq;
  this.lastAt = now;
  this.queue.push({seq, input:cancel ? {} : {...input}, at:now});
  return true;
 }
 expired(now) {
  return (this.queue.length && now - this.queue[0].at >= INPUT_TTL_MS) ||
   (this.lastAt !== null && now - this.lastAt >= INPUT_TTL_MS);
 }
 take() {
  const sample = this.queue.shift();
  if (!sample) return {seq:null, input:{...this.held}};
  this.held = {...sample.input};
  for (const field of PULSES) delete this.held[field];
  delete this.held.seq;
  return sample;
 }
 stepped(seq) { if (seq !== null) this.applied = seq; }
 status() {
  return {receivedSeq:this.received, appliedSeq:this.applied,
   cancelledThrough:this.cancelledThrough, queueDepth:this.queue.length};
 }
}
