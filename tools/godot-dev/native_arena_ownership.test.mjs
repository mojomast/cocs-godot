import test from 'node:test';
import {scenarios, verifyOwnership} from '../../port/native-arena-launchers/ownership-fixtures.mjs';

for (const scenario of scenarios) test(`dev Native DM SYNTHETIC ownership: ${scenario}`,()=>verifyOwnership('dev',scenario));
for (const map of ['aurora-basin','cinder-array']) test(`dev Native DM SYNTHETIC map routing: ${map}`,()=>verifyOwnership('dev','smoke',map));
test('dev Native DM SYNTHETIC hung smoke has a 20-second deadline',()=>verifyOwnership('dev','smoke-timeout'));
