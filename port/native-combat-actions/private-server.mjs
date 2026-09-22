// Ephemeral loopback endpoint; unmodified production clock and authority.
import { createGameServer } from '../../server/game-server.mjs';
const host = createGameServer({ port: 0 });
host.server.listen(0, '127.0.0.1', () => console.log(`COMBAT_ENDPOINT=ws://127.0.0.1:${host.server.address().port}`));
for (const signal of ['SIGINT', 'SIGTERM']) process.on(signal, async () => { await host.close(); process.exit(0); });
