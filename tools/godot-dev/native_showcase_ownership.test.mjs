// SYNTHETIC launcher-process regression only; source validation/Godot are stubs.
import test from 'node:test';
import {nativeScenes, verifyLifecycle} from '../../port/native-graphics-launchers/fixtures.mjs';

for (const experience of Object.keys(nativeScenes)) {
  for (const scenario of ['exit','smoke']) test(`source native-only stub: ${experience} ${scenario}`,()=>verifyLifecycle('dev',experience,scenario));
}
for (const scenario of ['native-failure','native-crash','missing-native','spawn-failure','wrong-version','invalid-lock','interrupt','terminate','uncooperative','bad-args','ambiguous-help']) {
  test(`source native-only stub ownership: ${scenario}`,()=>verifyLifecycle('dev','showcase',scenario));
}
