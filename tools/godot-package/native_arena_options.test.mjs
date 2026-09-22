import test from 'node:test';
import {options, EXPERIENCES, NATIVE_EXPERIENCES} from './options.mjs';
import {verifyOptions} from '../../port/native-arena-launchers/options-fixtures.mjs';

test('package Native DM strict options and source/exploration route separation',()=>verifyOptions(options,EXPERIENCES,NATIVE_EXPERIENCES));
