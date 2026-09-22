// SYNTHETIC launcher-process regression only; does not validate Godot or the PCK.
import test from 'node:test';
import {nativeScenes, verifyLifecycle} from '../../port/native-graphics-launchers/fixtures.mjs';

for (const experience of Object.keys(nativeScenes)) {
  for (const scenario of ['exit','smoke']) test(`package native-only stub: ${experience} ${scenario}`,()=>verifyLifecycle('package',experience,scenario));
}
for (const scenario of ['native-failure','native-crash','missing-native','interrupt','terminate','uncooperative','bad-args','ambiguous-help']) {
  test(`package native-only stub ownership: ${scenario}`,()=>verifyLifecycle('package','showcase',scenario));
}
