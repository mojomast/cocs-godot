import test from 'node:test';
import {scenarios, verifyOwnership} from '../../port/native-arena-launchers/ownership-fixtures.mjs';

for (const scenario of scenarios) test(`package Native DM SYNTHETIC ownership: ${scenario}`,()=>verifyOwnership('package',scenario));
for (const map of ['aurora-basin','cinder-array']) test(`package Native DM SYNTHETIC map routing: ${map}`,()=>verifyOwnership('package','smoke',map));
test('package Native DM SYNTHETIC hung smoke has a 20-second deadline',()=>verifyOwnership('package','smoke-timeout'));
