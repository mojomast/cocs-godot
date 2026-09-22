import test from 'node:test';
import {verifyActualFactory} from '../../port/native-arena-launchers/authority-fixtures.mjs';

for (const bots of [1,7,0,8]) test(`package Native DM actual factory, synthetic geometry/process: bots=${bots}`,()=>verifyActualFactory('package',bots));
