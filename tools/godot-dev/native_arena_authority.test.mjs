import test from 'node:test';
import {verifyFactoryBounds, verifyActualFactory} from '../../port/native-arena-launchers/authority-fixtures.mjs';

test('delivered authority rejects bot counts below 1 and above 24',verifyFactoryBounds);
for (const bots of [1,7,8,24,0,25]) test(`dev Native DM actual factory, synthetic geometry/process: bots=${bots}`,()=>verifyActualFactory('dev',bots));
