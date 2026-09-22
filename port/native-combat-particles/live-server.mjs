import { createGameServer } from '../../server/game-server.mjs';

// Ordinary server cadence and source rules. No registry/match state mutation,
// accelerated clock, or persisted history/progression files.
const { server, close } = createGameServer({ port: 4187 });
server.listen(4187, '127.0.0.1', () => console.log('COMBAT_PARTICLES_NORMAL_SERVER ws://127.0.0.1:4187'));
process.on('SIGTERM', async () => { await close(); process.exit(0); });
