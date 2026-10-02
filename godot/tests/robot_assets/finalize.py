"""Source-only grant-D handoff: verify owned process teardown and hash real evidence."""
import datetime
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[3]
EVIDENCE = Path('/home/mojo/.tmp-on-disk/cocs-expansion-three-robots-evidence-20261002/production-d')
STAGES = {
    'build':'20261002T230718.239830Z', 'reopenOriginal':'20261002T230728.406763Z',
    'reopen':'20261002T230733.650977Z', 'receiptOriginal':'20261002T230741.365446Z',
    'import':'20261002T230746.329863Z', 'native':'20261002T230755.229319Z',
    'galleryHigh':'20261002T230801.835440Z', 'galleryCompact':'20261002T231344.625768Z',
    'contacts':'20261002T230855.613635Z', 'targeting':'20261002T231001.062837Z',
    'production':'20261002T231013.811011Z', 'review':'20261002T231436.880071Z',
    'receipt':'20261002T231512.033428Z', 'packageReceipt':'20261002T231534.273214Z',
}


def read(stage, name):
    return json.loads((EVIDENCE / STAGES[stage] / name).read_text())


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


native = read('native', 'native.json')
contacts = read('contacts', 'contacts.json')
targeting = read('targeting', 'targeting.json')
assert not native['failures'] and not contacts['failures'] and not targeting['failures']
package_path = ROOT/'tools/godot-package/production_receipts/robots.json'
package = json.loads(package_path.read_text())
assert len(package['masters']) == 9 and len(package['exports']) == 9
for item in package['masters'] + package['exports']:
    assert sha(ROOT/item['path']) == item['sha256']
for path, digest in package['runtimeHooks'].items():
    assert sha(ROOT/path) == digest
for path, digest in package['packageInputs'].items():
    assert sha(ROOT/path) == digest
assert package['accepted'] is False
groups = sorted({json.loads(path.read_text())['processGroup'] for path in EVIDENCE.glob('*/*-process.json')})
processes = [line.split(None,3) for line in subprocess.check_output(['ps','-eo','pid=,pgid=,stat=,args='],text=True).splitlines()]
remaining = [row for row in processes if int(row[1]) in groups]
assert not remaining, remaining
hashes = {str(path.relative_to(EVIDENCE)):sha(path) for path in sorted(EVIDENCE.rglob('*'))
          if path.is_file() and path.suffix in ['.json','.log','.png','.mp4']}
manifest = {
    'grant':'ROBOT-ASSET-PRODUCTION-20261002-D', 'assetCommit':'3b6a3e79', 'runtimeHookCommit':'93622961',
    'evidenceRoot':str(EVIDENCE), 'stages':STAGES, 'sourceFingerprint':package['sourceFingerprint'],
    'packageReceiptSHA256':sha(package_path), 'nativeChecks':native['checks'],
    'contacts':contacts, 'targeting':targeting, 'review':read('review','review.json'),
    'production':[{k:v for k,v in item.items() if k!='receipt'} for item in read('production','production.json')['summary']],
    'evidenceSHA256':hashes, 'ownedGroups':groups, 'remainingOwnedProcesses':remaining,
    'promotionChanged':False, 'windowsExported':False,
    'evidenceLevel':'real Blender/native assets, controlled production-authority replay, llvmpipe captures; no human/GPU claim',
}
(ROOT/'tools/godot-robots/production-d.json').write_text(json.dumps(manifest,indent=2)+'\n')
release = {'grant':manifest['grant'],'released':True,'releasedAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),
           'ownedProcessGroups':groups,'ownedGroupsCount':len(groups),'remainingOwnedProcesses':remaining,
           'assetCommit':manifest['assetCommit'],'runtimeHookCommit':manifest['runtimeHookCommit'],
           'packageReceiptSHA256':manifest['packageReceiptSHA256'],'promotionChanged':False,
           'checkpoint':'robot production complete; no further heavy commands under grant D'}
(EVIDENCE/'HEAVY_GRANT_RELEASE.json').write_text(json.dumps(release,indent=2)+'\n')
print(json.dumps(release))
