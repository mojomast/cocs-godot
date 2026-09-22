import test from 'node:test';
import {verifyFactoryBounds, verifyActualFactory} from '../../port/native-arena-launchers/authority-fixtures.mjs';

test('delivered authority rejects source-clamped bot counts 0 and 8',verifyFactoryBounds);
for (const bots of [1,7,0,8]) test(`dev Native DM actual factory, synthetic geometry/process: bots=${bots}`,()=>verifyActualFactory('dev',bots));
