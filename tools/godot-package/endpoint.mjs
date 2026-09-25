// Shared launcher validation; packaged verbatim so play needs no source checkout.
export function lobbyEndpoint(value, experience) {
  if (value === undefined) return null;
  if (!['lobby', 'lattice', 'lattice-world'].includes(experience)) throw Error('--endpoint requires --experience=lobby, lattice or lattice-world');
  if (value.length > 2048 || /[\s\\]/.test(value) || !value.startsWith('ws://') && !value.startsWith('wss://')) throw Error('Invalid WebSocket endpoint');
  let url;
  try { url = new URL(value); } catch { throw Error('Invalid WebSocket endpoint'); }
  if (!['ws:', 'wss:'].includes(url.protocol) || !url.hostname || url.username || url.password || url.hash) {
    throw Error('Use a ws:// or wss:// endpoint without embedded credentials or fragments');
  }
  return value;
}
