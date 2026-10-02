"""Copy immutable Parallax / restored-light native captures into a fresh gallery."""
import argparse
import hashlib
import html
import json
import shutil
from pathlib import Path


def publish(evidence, destination):
    release = json.loads((evidence / "HEAVY_GRANT_RELEASE.json").read_text())
    assert release["status"] == "EXPLICITLY RELEASED"
    assert release["remainingLiveOwnedProcesses"] == []
    destination.mkdir(parents=True, exist_ok=False)
    records, sections = [], []

    def copy(source):
        relative = source.relative_to(evidence)
        target = destination / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
        data = source.read_bytes()
        assert target.read_bytes() == data
        records.append({"path": relative.as_posix(), "bytes": len(data),
                        "sha256": hashlib.sha256(data).hexdigest()})
        return html.escape(relative.as_posix(), quote=True)

    def image(source, caption):
        path = copy(source)
        text = html.escape(caption)
        return f'<figure><a href="{path}"><img loading="lazy" src="{path}" alt="{text}"></a><figcaption>{text}</figcaption></figure>'

    views = ["overview", "archive-interior", "archive-storage", "archive-retrieval",
             "pump-interior", "pump-hydraulics", "archive-portal", "pump-portal",
             "polar-interior", "arrival-eye", "arcade-eye", "cistern-eye", "lens-eye"]
    for name in views:
        sections.append(f'<h2>{html.escape(name)}</h2><div class="pair">')
        for mode in ["off", "full"]:
            sections.append(image(evidence / "native-review" / f"{name}-{mode}.png",
                                  "Revised interiors — dressing " + mode))
        sections.append('</div>')
    sections.append('<h2>Foundry lights: source / pre-fix refined / restored refined</h2>')
    for name in ["cooling-lights", "furnace-sight-glass", "assay-status-lamp"]:
        sections.append(f'<h3>{name}</h3><div class="triple">')
        for variant, label in [("flat", "Original source material"),
                               ("rejected", "Refined finish before light fix"),
                               ("refined", "Refined finish with source lights restored")]:
            sections.append(image(evidence / "emission-followup" / name /
                                  f"gravemill-foundry-{variant}-000.png", label))
        sections.append('</div>')
        copy(evidence / "emission-followup" / name / "gravemill-foundry-refinement.json")
    copy(evidence / "native-review" / "inspection.json")
    copy(evidence / "HEAVY_GRANT_RELEASE.json")
    document = '''<!doctype html><html lang="en"><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1"><title>Parallax interiors and restored Foundry lights</title>
<style>body{margin:0 auto;padding:24px;max-width:1500px;background:#141922;color:#edf0f5;font:16px/1.5 system-ui}a{color:#9ed8ff}img{max-width:100%;height:auto}figure{margin:12px 0}figcaption{color:#bdcad6}.pair,.triple{display:grid;gap:12px;grid-template-columns:repeat(2,minmax(0,1fr))}.triple{grid-template-columns:repeat(3,minmax(0,1fr))}h2{margin-top:40px}@media(max-width:700px){.pair,.triple{grid-template-columns:1fr}}</style>
<h1>Parallax interiors &amp; restored Foundry lights</h1>
<p>Actual Godot production-C captures, October 2, 2026. Revised archive storage/retrieval equipment, pump hydraulics and distinct ceilings. Both Parallax columns show the same revised geometry; Off/Full refers to surface dressing, not old/new architecture.</p>
<p>Foundry comparisons show the original source, the refined finish before its lighting correction, and the restored original light material. These are retained software-rendered review captures, not real-GPU performance measurements or a final release attestation. Click any image for original resolution.</p>
<p><a href="../native-production-b/">Earlier surface comparisons and nine-fighter clips</a> · <a href="manifest.json">Image SHA-256 inventory</a></p>
'''+"\n".join(sections)+"\n</html>\n"
    (destination / "index.html").write_text(document)
    (destination / "manifest.json").write_text(json.dumps({"source_commit": release["head"],
        "grant": release["grant"], "files": records}, indent=2)+"\n")
    print(json.dumps({"files": len(records), "bytes": sum(r["bytes"] for r in records),
                      "destination": str(destination)}))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("--destination", type=Path, required=True)
    args = parser.parse_args()
    publish(args.evidence.resolve(), args.destination.resolve())
