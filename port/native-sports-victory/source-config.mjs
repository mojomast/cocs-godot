// Read-only constructor/config inspection, no stepping and no scoring claim.
import assert from 'node:assert/strict';
import {Match} from '../../game/core.mjs';
import {normalizeConfig} from '../../game/config.mjs';
const requested={mode:'puma-soccer',botCount:0,timeLimit:180,fragLimit:15};
const before=JSON.stringify(requested);
const normalized=normalizeConfig(requested);
const match=new Match('chatgpt','openclaw',Math.random,'aurora-stadium',requested);
assert.equal(JSON.stringify(requested),before);
assert.equal(normalized.botCount,0);
assert.equal(match.config.botCount,3);
assert.equal(match.actors.length,4);
assert.equal(match.actors.filter(actor=>actor.bot).length,3);
console.log(JSON.stringify({classification:'constructor inspection only; no simulation steps',requested,normalizedBotCount:normalized.botCount,effectiveBotCount:match.config.botCount,roles:match.actors.map(({id,team,bot})=>({id,team,bot:Boolean(bot)})),conclusion:'A zero-bot solo host preset is unsupported by this source. No bot disabling or fake human seats applied.'},null,2));
