"""Offline specification validation; never gameplay execution or acceptance proof."""
import argparse
import json
from pathlib import Path

CLASSES = {'source_inspection', 'synthetic', 'recorded_replay', 'live_automated', 'manual_acceptance'}
STATUSES = {'inspected', 'reported', 'pending'}
TEXT_FIELDS = ('id', 'title', 'map', 'mode', 'pass_criteria', 'fail_criteria')
LIST_FIELDS = ('prerequisites', 'actions', 'authority', 'native', 'capture', 'questions')


def validate(data):
    errors = []
    def error(where, message):
        errors.append(f'{where}: {message}')
    def texts(value, where, nonempty=True):
        if not isinstance(value, list) or (nonempty and not value):
            error(where, 'expected nonempty list' if nonempty else 'expected list')
            return []
        for i, text in enumerate(value):
            if not isinstance(text, str) or not text.strip():
                error(f'{where}[{i}]', 'expected nonblank string')
        return [x for x in value if isinstance(x, str) and x.strip()]
    if not isinstance(data, dict):
        return ['catalog: expected object']
    if type(data.get('schema_version')) is not int or data['schema_version'] != 1:
        error('schema_version', 'expected integer 1')
    for field in ('base_commit', 'purpose'):
        if not isinstance(data.get(field), str) or not data[field].strip():
            error(field, 'expected nonblank string')
    tables = {}
    for name in ('evidence', 'scenarios'):
        rows = data.get(name)
        if not isinstance(rows, list) or not rows:
            error(name, 'expected nonempty list')
            rows = []
        tables[name] = {}
        for i, row in enumerate(rows):
            loc = f'{name}[{i}]'
            if not isinstance(row, dict):
                error(loc, 'expected object')
                continue
            rid = row.get('id')
            if not isinstance(rid, str) or not rid.strip():
                error(loc + '.id', 'expected nonblank string')
                continue
            if rid in tables[name]:
                error(loc + '.id', f'duplicate ID {rid}')
            tables[name][rid] = row
    for rid, row in tables['evidence'].items():
        loc = f'evidence.{rid}'
        if not isinstance(row.get('classification'), str) or row['classification'] not in CLASSES:
            error(loc + '.classification', 'expected explicit evidence classification')
        if not isinstance(row.get('status'), str) or row['status'] not in STATUSES:
            error(loc + '.status', 'expected inspected, reported or pending')
        for key in ('reference', 'claim', 'limitation'):
            if not isinstance(row.get(key), str) or not row[key].strip():
                error(loc + '.' + key, 'expected nonblank string')
    for rid, row in tables['scenarios'].items():
        loc = f'scenarios.{rid}'
        for key in TEXT_FIELDS:
            if not isinstance(row.get(key), str) or not row[key].strip():
                error(loc + '.' + key, 'expected nonblank string')
        for key in LIST_FIELDS:
            texts(row.get(key), loc + '.' + key, key != 'questions')
        for key, table in [('evidence_refs', 'evidence'), ('depends_on', 'scenarios')]:
            refs = texts(row.get(key), loc + '.' + key, key == 'evidence_refs')
            for ref in refs:
                if ref not in tables[table]: error(loc + '.' + key, f'unknown reference {ref}')
                if table == 'scenarios' and ref == rid: error(loc + '.' + key, 'self dependency')
        if row.get('acceptance_status') != 'pending':
            error(loc + '.acceptance_status', 'audit scenarios must remain pending; validator is not gameplay proof')
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('catalog', type=Path)
    args = parser.parse_args()
    try:
        data = json.loads(args.catalog.read_text())
    except (OSError, ValueError) as exc:
        print(f'catalog: {exc}')
        return 2
    errors = validate(data)
    for error in errors: print(error)
    if errors: return 1
    print(f'SPEC_VALID scenarios={len(data["scenarios"])} evidence={len(data["evidence"])}; gameplay acceptance NOT evaluated')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
