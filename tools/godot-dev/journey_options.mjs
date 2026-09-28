import assert from 'node:assert/strict';

export const DEFAULT_ITINERARY = [
  {route:'combat', options:{}},
  {route:'lattice-world', options:{}},
  {route:'sports', options:{}},
];

// A bounded test itinerary, not another playable-route registry. Route existence,
// ownership and option keys come from the generated product registry. The real
// Home controls and launch parser still validate selected values during the run.
export function journeyOptions(raw, registry) {
  assert.ok(Array.isArray(raw) && raw.length > 0 && raw.length <= 6, 'Select 1–6 itinerary entries');
  return raw.map(entry => {
    assert.ok(entry && typeof entry === 'object' && !Array.isArray(entry), 'Invalid itinerary entry');
    assert.ok(Object.keys(entry).every(key => ['route','options'].includes(key)), 'Unknown itinerary field');
    const route = registry.routes.find(route => route.id === entry.route);
    assert.ok(route && route.category !== 'cheats', 'Unknown or debug-only itinerary route');
    assert.ok(route.capability?.authority?.local && !route.capability.authority.offline,
      'Journey entries must own a source authority');
    const options = entry.options ?? {};
    assert.ok(options && typeof options === 'object' && !Array.isArray(options), 'Invalid itinerary options');
    for (const [key, value] of Object.entries(options)) {
      const param = route.params.find(param => param.key === key);
      assert.ok(param && ['choice','range'].includes(param.kind), `Unsupported journey option: ${key}`);
      assert.ok(param.kind === 'choice' ? typeof value === 'string' : Number.isFinite(value), `Invalid journey option type: ${key}`);
    }
    return {route:route.id, options:{...options}};
  });
}
