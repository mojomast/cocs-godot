import {readFileSync,existsSync} from 'node:fs';
import {join} from 'node:path';
import {productionResources} from '../../godot-package/production_resources.mjs';
import {WORLDS} from '../../../port/multiplayer-worlds/catalog.mjs';
import {root,sha256} from './contracts.mjs';

// Consume the packaging owner's actual promotion/GLB/fingerprint validator.
// Presence of optional runtime fallbacks is never asset-production acceptance.
export function assetInputs({strict=false}={}) {
  const inventory=productionResources({read:p=>readFileSync(join(root,p)),has:p=>existsSync(join(root,p)),worldIds:Object.keys(WORLDS),strict});
  const files={...inventory.resources,...inventory.provenance};
  return {pending:inventory.pending,registeredWorlds:Object.keys(WORLDS).sort(),
    files,sha256:sha256(JSON.stringify(files)),requiredShotUnits:['robots','scenery'],
    releaseSequence:'Capture after all seven final production promotions, without adding multiplayer/fighting story shots',
    requiredNativeSkins:{skirmisher:'needle_surveyor',bulwark:'caisson_guard',mortar:'kiln_tender'}};
}

export function assertAssetIdentity(expected,actual) {
  if(!expected||actual.pending.length||expected.sha256!==actual.sha256)throw Error('Required shot assets missing/pending or changed; prepare a new attempt after accepted production');
}
