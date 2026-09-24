import {parseDebugFrame} from '../native-debug/debug.mjs';

/** Extend only local route bot-count validation; shared debug semantics and all
 * other routes keep their source-owned parser and 0..8 range. */
export function parseLocalDebugFrame(frame, [min, max]) {
  // Spreading a class instance/array would erase its prototype before the
  // shared parser's plain-object check. Keep that envelope gate intact.
  if (frame === null || typeof frame !== 'object' || Array.isArray(frame) ||
      ![Object.prototype, null].includes(Object.getPrototypeOf(frame))) {
    return parseDebugFrame(frame);
  }
  if (frame?.botCount === undefined) return parseDebugFrame(frame);
  const count = frame.botCount;
  if (!Number.isInteger(count) || count < min || count > max) {
    throw new TypeError(`botCount must be an integer in ${min}..${max}`);
  }
  const parsed = parseDebugFrame({...frame, botCount:Math.min(8, Math.max(0, count))});
  parsed.set.botCount = count;
  return parsed;
}
