"""Read-only, three-pass local native-slot release audit. Never kills processes."""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import time


def processes(groups, workspace, evidence):
    matches=[]
    foreign_native=[]
    for entry in Path('/proc').iterdir():
        if not entry.name.isdecimal() or int(entry.name)==os.getpid(): continue
        try:
            fields=(entry/'stat').read_text().rsplit(') ',1)[1].split()
            group=int(fields[2])
            command=(entry/'cmdline').read_bytes().replace(b'\0',b' ').decode(errors='replace')
            comm=(entry/'comm').read_text().strip()
            try: cwd=str((entry/'cwd').resolve(strict=True))
            except (FileNotFoundError,PermissionError): cwd=''
            try: environment=(entry/'environ').read_bytes().decode(errors='replace')
            except PermissionError: environment=''
        except (FileNotFoundError,ProcessLookupError,PermissionError): continue
        # Audit retained groups plus native executables and lane-tagged children.
        # Early run_bounded receipts lack PGIDs but include reaped/empty descendant
        # results, so also scan executables and isolated evidence environments.
        native=comm.lower().startswith(('godot','xvfb'))
        tagged=evidence in environment or (workspace in command and comm in ['node','python3']) or (native and cwd==workspace)
        row={'pid':int(entry.name),'pgid':group,'state':fields[0],'comm':comm,'command':command,'cwd':cwd}
        if group in groups or tagged: matches.append(row)
        elif native: foreign_native.append(row)
    return matches,foreign_native


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--evidence',type=Path,required=True)
    parser.add_argument('--grant',required=True)
    parser.add_argument('--receipt-name',default='release-K')
    parser.add_argument('--extra-workspace',action='append',default=[])
    args=parser.parse_args()
    groups=set(); receipts=[]; legacy=0
    for path in args.evidence.glob('*/queue.json'):
        report=json.loads(path.read_text())
        if report.get('grant')!=args.grant: continue
        for row in report['attempts']:
            if row.get('owned_process_group'): groups.add(row['owned_process_group'])
            else: legacy+=1
            if row.get('cleanup',{}).get('remaining'): raise SystemExit('Nonempty retained cleanup: '+str(path))
        receipts.append(str(path))
    for path in args.evidence.glob('*/live-kick/producer/summary.json'):
        report=json.loads(path.read_text())
        if report.get('grant_id')!=args.grant: continue
        for row in report['cleanup']:
            groups.add(row['pgid'])
            if row.get('final_survivors'): raise SystemExit('Live-kick survivors: '+str(path))
        receipts.append(str(path))
    audits=[]
    for index in range(3):
        found,foreign=processes(groups,str(Path(__file__).resolve().parents[2]),str(args.evidence.resolve()))
        for workspace in args.extra_workspace:
            extra,_=processes(groups,str(Path(workspace).resolve()),str(args.evidence.resolve()))
            known={row['pid'] for row in found}
            found.extend(row for row in extra if row['pid'] not in known)
        audits.append({'at':datetime.now(timezone.utc).isoformat(),'matches':found,'unowned_native_observations':foreign})
        if found: break
        if index<2: time.sleep(0.3)
    released=len(audits)==3 and not any(a['matches'] for a in audits)
    result={'grant':args.grant,'released':released,'owned_groups':sorted(groups),
            'legacy_attempts_with_reaped_descendant_receipts_but_no_pgid':legacy,
            'receipts':receipts,'audits':audits,'scope':'all retained groups and lane command/environment/cwd tags; unrelated browser/viewer native services recorded separately, never signalled'}
    target=args.evidence/(args.receipt_name+('.json' if released else '-blocked.json'))
    with target.open('x') as stream: json.dump(result,stream,indent=2)
    print(json.dumps({'released':released,'groups':len(groups),'audits':len(audits),'path':str(target)}))
    return 0 if released else 1

if __name__=='__main__': raise SystemExit(main())
