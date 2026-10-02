/** Expand authored sparse commands; this contains no combat simulation. */
export function expandTrace(combo, facing = 1, tail = 100) {
  if (![1, -1].includes(facing)) throw new Error('facing must be ±1');
  const samples = [...(combo.setup_inputs ?? []), ...combo.inputs];
  let end = 0;
  for (const sample of samples) {
    for (const key of ['tick', 'axis_x', 'axis_y', 'held', 'pressed']) {
      if (!Number.isSafeInteger(sample[key])) throw new Error(`invalid ${key}`);
    }
    if (sample.tick < 0 || Math.abs(sample.axis_x) > 1 || Math.abs(sample.axis_y) > 1 ||
        sample.held < 0 || sample.held > 511 || sample.pressed < 0 || sample.pressed > 511) {
      throw new Error('command out of bounds');
    }
    const duration = sample.duration ?? 1;
    if (!Number.isSafeInteger(duration) || duration < 1 || duration > 600) throw new Error('invalid duration');
    end = Math.max(end, sample.tick + duration);
  }
  return Array.from({length: end + tail}, (_, tick) => {
    const active = samples.filter(s => tick >= s.tick && tick < s.tick + (s.duration ?? 1));
    if (active.length > 1) throw new Error(`ambiguous overlapping samples at ${tick}`);
    const s = active[0];
    return s ? {axis_x: s.axis_x * facing, axis_y: s.axis_y, held: s.held, pressed: s.pressed}
      : {axis_x: 0, axis_y: 0, held: 0, pressed: 0};
  });
}
