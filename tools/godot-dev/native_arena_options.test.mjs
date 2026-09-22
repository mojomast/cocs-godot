import test from 'node:test';
import {launchOptions, EXPERIENCES, NATIVE_EXPERIENCES} from './launch_options.mjs';
import {verifyOptions} from '../../port/native-arena-launchers/options-fixtures.mjs';

test('dev Native DM strict options and source/exploration route separation',()=>verifyOptions(launchOptions,EXPERIENCES,NATIVE_EXPERIENCES));
