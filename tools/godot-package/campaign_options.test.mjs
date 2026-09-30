import test from 'node:test';
import assert from 'node:assert/strict';
import {options} from './options.mjs';
import {launchOptions} from '../godot-dev/launch_options.mjs';
import {acquireCareer} from './career_path.mjs';

const maps = ['rootfall-verge','siltwake-crossing','emberline-ascent','crown-array'];
for (const [name, parse] of [['package',options],['development',launchOptions]]) {
  test(`${name}: campaign chapter/difficulty parity independent of locked catalog`, () => {
    for (const map of maps) for (const difficulty of ['easy','normal','hard']) {
      const plan = parse(['--experience=campaign',`--map=${map}`,'--mode=campaign',`--difficulty=${difficulty}`,'--smoke','--diagnostics'], {maps:[]});
      assert.equal(plan.campaign, true);
      assert.equal(plan.endpoint, null);
      assert.equal(plan.nativeOnly, undefined);
      assert.equal(plan.map, map);
      assert.equal(plan.difficulty, difficulty);
      assert.deepEqual(plan.userArgs ?? plan.sessionOptions, [`--map=${map}`,'--mode=campaign',`--difficulty=${difficulty}`,'--diagnostics','--smoke']);
      assert.ok(plan.scene === 'res://campaign/demo.tscn' || plan.args?.includes('res://campaign/demo.tscn'));
      const career = acquireCareer(plan, {}, {home:'/unused/campaign-test'});
      assert.equal(career.progressionPath, null);
      assert.equal(career.env.COCS_CAREER_SCOPE, '');
    }
    const defaults = parse(['--experience=campaign'], {maps:[]});
    assert.equal(defaults.map, maps[0]);
    assert.equal(defaults.difficulty, 'normal');
  });
  test(`${name}: campaign rejects multiplayer, overrides and malformed arguments`, () => {
    for (const arg of ['--map=meridian-exchange','--map=../rootfall-verge','--map=constructor','--mode=deathmatch','--difficulty=Normal','--difficulty=','--endpoint=ws://127.0.0.1:1234/native-campaign','--endpoint=wss://example.org','--join-room=room','--bots=0','--round-seconds=120','--time-limit=300','--waves=5','--operator=chatgpt','--harness=opencode','--wait-for-players=2','--rung=4v4','--setup','--play','--debug-panel','--mute','--native-trace']) {
      assert.throws(() => parse(['--experience=campaign',arg], {maps:[]}), arg);
    }
    assert.throws(() => parse(['--experience=campaign','--difficulty=easy','--difficulty=hard'], {maps:[]}));
    assert.throws(() => parse(['--experience=campaign','--map'], {maps:[]}));
    assert.throws(() => parse(['--experience=combat','--difficulty=normal'], {maps:[]}));
  });
}
