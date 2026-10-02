"""Read-only, exact-anchor receipt adapters. Never execute producers or bless plans."""
import hashlib
import json
from pathlib import Path


def sha(path):
    digest = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()


def checked_file(record):
    path = Path(record['path'])
    if not path.is_absolute() or not path.is_file() or path.is_symlink():
        raise ValueError('Receipt artifact must be an existing absolute regular file')
    if sha(path) != record['sha256']:
        raise ValueError('Receipt artifact bytes changed: ' + str(path))
    return path


def require_complete(data):
    if data.get('status') != 'passed' or data.get('executed') is not True:
        raise ValueError('Ready/deferred/skipped/unexecuted is not acceptance')
    if any(data.get(key) for key in ('failures', 'unrun', 'missing', 'incomplete_critical')):
        raise ValueError('Receipt retains unresolved critical cases')


def check_units(data, job):
    expected = set(job.get('units', []))
    units = data.get('units', {})
    if not expected or set(units) != expected or any(v != 'passed' for v in units.values()):
        raise ValueError('Exact requested units must all have executed passing evidence')


def check_resource_outputs(data, job, root):
    """Missing art cannot be waived by a ready recipe or by a fixture elsewhere."""
    kind = job.get('output_kind')
    if not kind:
        return
    resources = data.get('resources', {})
    if set(resources) != set(job['units']):
        raise ValueError('Every requested unit needs its actual exported resources')
    for unit, entries in resources.items():
        if not entries:
            raise ValueError('No production output for ' + unit)
        for item in entries:
            name = Path(item['path'])
            if name.is_absolute() or '..' in name.parts:
                raise ValueError('Resource path must be checkout-relative')
            path = root / name
            if not path.is_file() or path.is_symlink() or not path.resolve().is_relative_to(root.resolve()):
                raise ValueError('Missing real production resource: ' + str(name))
            if sha(path) != item['sha256']:
                raise ValueError('Production resource hash mismatch')
            if kind == 'glb':
                with path.open('rb') as stream:
                    header = stream.read(12)
                if (path.suffix != '.glb' or len(header) != 12 or header[:4] != b'glTF'
                        or int.from_bytes(header[4:8], 'little') != 2
                        or int.from_bytes(header[8:12], 'little') != path.stat().st_size):
                    raise ValueError('Expected an actual exported GLB, not a recipe/placeholder')


def windows_result(data, artifacts, root):
    """Consume the existing platform verifier, package manifest and actual CI proof."""
    roles = data.get('roles', {})
    needed = ('windows_report', 'package_manifest', 'manifest_validation', 'windows_graphical',
              'windows_ci', 'pck', 'executable', 'archive')
    if not set(needed) <= set(roles) or any(roles[key] not in artifacts for key in needed):
        raise ValueError('Actual Windows report/CI/manifest/PCK/exe/archive artifacts required')
    native = json.loads(artifacts[roles['windows_report']].read_text())
    manifest_path = artifacts[roles['package_manifest']]
    manifest = json.loads(manifest_path.read_text())
    ci = json.loads(artifacts[roles['windows_ci']].read_text())
    validated = json.loads(artifacts[roles['manifest_validation']].read_text())
    graphical = json.loads(artifacts[roles['windows_graphical']].read_text())
    if native.get('platform') != 'win32' or native.get('status') != 'passed':
        raise ValueError('Actual Windows verifier pass required, not Linux/Wine/source-only')
    cases = native.get('cases', [])
    if not cases or any(case.get('passed') is not True for case in cases):
        raise ValueError('Incomplete Windows cases')
    if (manifest.get('target') != 'windows' or native.get('manifest_sha256') != sha(manifest_path)
            or not native.get('port_commit') or native['port_commit'] != manifest.get('port_commit')):
        raise ValueError('Windows report/package identity mismatch')
    if (validated.get('status') != 'passed' or validated.get('target') != 'windows'
            or validated.get('port_commit') != manifest['port_commit']):
        raise ValueError('Packaging-owned manifest/provenance validation must pass')
    visual_units = {'fighting-Home-and-nine-rigs', 'three-map-and-operator-finishes', 'replay-runtime', 'main-menu'}
    visual_cases = graphical.get('cases', [])
    if (graphical.get('platform') != 'win32' or graphical.get('status') != 'passed'
            or graphical.get('graphical') is not True or graphical.get('port_commit') != manifest['port_commit']
            or not visual_units <= {case.get('unit') for case in visual_cases}
            or any(case.get('passed') is not True for case in visual_cases)):
        raise ValueError('Actual extracted Windows graphical feature journeys remain required')
    for role, name in (('pck', 'cocs.pck'), ('executable', 'cocs.exe')):
        if manifest.get('files', {}).get(name) != sha(artifacts[roles[role]]):
            raise ValueError('Windows manifest does not bind shipped ' + name)
    if (ci.get('conclusion') != 'success' or ci.get('platform') != 'win32'
            or ci.get('clean_extraction') is not True or ci.get('used_checkout_runtime') is not False
            or not str(ci.get('run_url', '')).startswith('https://') or ci.get('port_commit') != manifest['port_commit']
            or ci.get('archive_sha256') != sha(artifacts[roles['archive']])):
        raise ValueError('Clean actual Windows CI/archive proof missing or inconsistent')
    # Package provenance is owned by packaging, not reimplemented here. Its exact
    # committed input map must bind all listed current runtime bytes, with no omissions.
    inputs = data.get('package_inputs', {})
    if inputs != manifest.get('inputs'):
        raise ValueError('Package input closure must exactly match the build manifest')
    if not inputs or not {'godot/project.godot', 'tools/godot-package/verify_windows.mjs'} <= set(inputs):
        raise ValueError('Recorded package input closure required')
    for name, expected in inputs.items():
        path = root / name
        if Path(name).is_absolute() or '..' in Path(name).parts or not path.is_file() or sha(path) != expected:
            raise ValueError('Windows package input bytes differ: ' + name)


def accept_reference(reference_path, report, jobs, root, archive=None):
    reference_bytes = Path(reference_path).read_bytes()
    reference = json.loads(reference_bytes)
    if not isinstance(reference, dict):
        raise ValueError('Receipt reference must be an object')
    job = next((j for j in jobs if j['id'] == reference.get('gate')), None)
    if not job:
        raise ValueError('Unknown receipt gate')
    producer_path = checked_file(reference['report'])
    producer_bytes = producer_path.read_bytes()
    producer_hash = hashlib.sha256(producer_bytes).hexdigest()
    if producer_hash != reference['report']['sha256']:
        raise ValueError('Producer receipt changed while reading')
    producer = json.loads(producer_bytes)
    if not isinstance(producer, dict):
        raise ValueError('Producer receipt must be an object')
    if producer.get('input_identity') != report['input_identity']:
        raise ValueError('Different exact input anchor; do not re-stamp historical evidence')
    for name in job.get('requires', []):
        if not (root / name).is_file():
            raise ValueError('Required real input missing: ' + name)
    for dependency in job.get('after', []):
        attempts = report['attempts'].get(dependency, [])
        if not attempts or attempts[-1]['status'] != 'passed':
            raise ValueError('Receipt prerequisite incomplete: ' + dependency)
    adapter = reference.get('adapter')
    if adapter == 'finish-job':
        if job.get('receipt_only'):
            raise ValueError('Owner closures require their typed adapter, not an executable receipt')
        source_job = next((j for j in producer.get('queue', []) if j['id'] == job['id']), None)
        if source_job != job:
            raise ValueError('Receipt job contract/resource classification differs')
        attempts = producer.get('attempts', {}).get(job['id'], [])
        if not attempts:
            raise ValueError('Producer has no executed attempt')
        attempt = attempts[-1]
        if (attempt.get('status') != 'passed' or attempt.get('exit_code') != 0
                or attempt.get('failure_reason') or attempt.get('receipt_reference')
                or attempt.get('cleanup', {}).get('remaining')):
            raise ValueError('Only an original, successful executed attempt can be reused')
        scope = Path(attempt.get('scope', ''))
        hashes = attempt.get('artifact_hashes', {})
        if not scope.is_absolute() or 'output.log' not in hashes:
            raise ValueError('Producer lacks execution-time artifact hashes; raw historical logs are insufficient')
        for name, expected in hashes.items():
            if Path(name).is_absolute() or '..' in Path(name).parts:
                raise ValueError('Invalid artifact scope')
            checked_file({'path': str(scope / name), 'sha256': expected})
        accepted = dict(attempt)
    elif adapter == 'owner-closure':
        if not job.get('receipt_only') or producer.get('gate') != job['id']:
            raise ValueError('Owner closure cannot replace runnable gate')
        if (producer.get('resource_class') != job['cohort']
                or producer.get('evidence_kind') != job['evidence_kind'] or not producer.get('owner')):
            raise ValueError('Source/manual/native/audio/external evidence classes cannot be substituted')
        require_complete(producer)
        check_units(producer, job)
        artifact_records = producer.get('artifacts', {})
        if not artifact_records:
            raise ValueError('Executed closure needs retained evidence')
        artifacts = {name: checked_file(item) for name, item in artifact_records.items()}
        execution = json.loads(artifacts[producer.get('execution_report', '')].read_text()) if producer.get('execution_report') in artifacts else None
        if (not execution or execution.get('status') != 'passed'
                or not (execution.get('checks') or execution.get('cases'))
                or any(execution.get(key) for key in ('failures', 'unrun', 'missing'))):
            raise ValueError('Actual nonempty executed producer report is required, not only an owner summary')
        check_resource_outputs(producer, job, root)
        if job.get('receipt_policy') == 'windows-release':
            windows_result(producer, artifacts, root)
        accepted = {'status': 'passed', 'executed': True, 'units': producer['units'],
                    'resource_class': producer['resource_class'], 'evidence_kind': producer['evidence_kind']}
    else:
        raise ValueError('Unsupported receipt adapter')
    accepted['receipt_reference'] = {'path': str(producer_path), 'sha256': producer_hash,
                                     'adapter': adapter, 'reference_sha256': hashlib.sha256(reference_bytes).hexdigest()}
    if archive is not None:
        archive.mkdir(parents=True, exist_ok=True)
        destination = archive / (producer_hash + '.json')
        if destination.exists():
            if sha(destination) != producer_hash:
                raise ValueError('Archived producer receipt changed')
        else:
            with destination.open('xb') as stream:
                stream.write(producer_bytes)
        accepted['receipt_reference']['archived_report'] = str(destination)
    report['attempts'].setdefault(job['id'], []).append(accepted)


def validate_artifact_checks(job, directory, root):
    """Narrow producer-specific checks; use existing evidence, not a second test engine."""
    units = {}
    for check in job.get('artifact_checks', []):
        paths = list(directory.glob(check['path']))
        if len(paths) != 1:
            raise ValueError('Expected one producer report: ' + check['path'])
        data = json.loads(paths[0].read_text())
        if check['kind'] == 'combos':
            roster = json.loads((root / 'godot/fighting/data/roster.json').read_text())
            expected = {(op['id'], c['name'], facing) for op in roster['operators'] for c in op['combos'] for facing in (1, -1)}
            rows = data.get('results', [])
            observed = {(r.get('operator'), r.get('name'), r.get('facing')) for r in rows}
            if observed != expected or len(rows) != len(expected) or data.get('failures') != 0:
                raise ValueError('Every authored combo in both facings must actually pass; no duplicates/omissions')
            for row in rows:
                if not all(row.get(k) is True for k in ('passed', 'continuous', 'replay_equal')) or not row.get('contacts'):
                    raise ValueError('Failed actual contact/continuity/replay combo')
                units[f"{row['operator']}/{row['name']}/{row['facing']}"] = 'passed'
        elif check['kind'] == 'map-finish':
            if (data.get('map') != check['map'] or data.get('failures') != []
                    or data.get('initial', {}).get('status') != 'ready'
                    or data.get('reloaded', {}).get('status') != 'ready'
                    or data.get('owned_max') != 1 or not data.get('frame_usec')):
                raise ValueError('Map finish actual coverage/lifecycle proof incomplete')
        elif check['kind'] == 'fighting-manifest':
            if data.get('status') != 'passed' or data.get('mode') not in ('source', 'native'):
                raise ValueError('Fighting producer is only prepared/deferred/failed')
            if data.get('candidate_after') != data.get('candidate', {}).get('sha256'):
                raise ValueError('Fighting inputs changed during execution')
        else:
            raise ValueError('Unknown producer artifact check')
    return units
