// Independent review harness helpers (review lane owns this file).
// No production module is modified; everything here is new review-only code.
import {createHash} from 'node:crypto';

export function seededRandom(seed = 987654321) {
  let s = seed >>> 0;
  return () => { s = (Math.imul(s, 1664525) + 1013904223) >>> 0; return s / 4294967296; };
}

// Independent canonical JSON + hash, written from the documented contract
// (recursive lexicographic key order, preserved array order, JSON.stringify
// number semantics). Used to re-verify the delivered geometryHash values.
export function canonicalJSON(value) {
  if (Array.isArray(value)) return `[${value.map(canonicalJSON).join(',')}]`;
  if (value !== null && typeof value === 'object') {
    return `{${Object.keys(value).sort().map(k => `${JSON.stringify(k)}:${canonicalJSON(value[k])}`).join(',')}}`;
  }
  return JSON.stringify(value) ?? 'null';
}

export function sha256(value) {
  return createHash('sha256').update(canonicalJSON(value)).digest('hex');
}

export function quantile(values, q) {
  if (!values.length) return null;
  const sorted = [...values].sort((a, b) => a - b);
  const pos = (sorted.length - 1) * q;
  const lo = Math.floor(pos), hi = Math.ceil(pos);
  if (lo === hi) return sorted[lo];
  return sorted[lo] + (sorted[hi] - sorted[lo]) * (pos - lo);
}
