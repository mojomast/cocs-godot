"""Publish retained native production-B captures without rendering or re-encoding."""
import argparse
import hashlib
import html
import json
import shutil
from pathlib import Path


def publish(evidence: Path, destination: Path):
    if destination.exists():
        raise SystemExit(f"Refusing to overwrite retained gallery: {destination}")
    surface = evidence / "surface-refinement-b"
    production = evidence / "production-b"
    release = json.loads((production / "HEAVY_GRANT_RELEASE.json").read_text())
    if not release.get("released") or release.get("matching_owned_heavy_processes"):
        raise SystemExit("Production grant has no clean release receipt")
    districts = sorted(p for p in surface.iterdir() if p.is_dir()
                       and list(p.glob("*-refinement.json"))
                       and len(list(p.glob("*-refined-000.png"))) == 1)
    stationary = [p for p in districts if len(list(p.glob("*-refined-*.png"))) == 1]
    if len(stationary) != 11:
        raise SystemExit(f"Expected eleven stationary districts, got {len(stationary)}")
    destination.mkdir(parents=True)
    records = []

    def copy(source: Path):
        relative = source.relative_to(evidence)
        target = destination / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
        digest = hashlib.sha256(source.read_bytes()).hexdigest()
        if hashlib.sha256(target.read_bytes()).hexdigest() != digest:
            raise SystemExit(f"Copy hash mismatch: {relative}")
        records.append({"path": relative.as_posix(), "sha256": digest,
                        "bytes": target.stat().st_size})
        return html.escape(relative.as_posix(), quote=True)

    def image(source: Path, caption: str):
        path = copy(source)
        label = html.escape(caption)
        return (f'<figure><a href="{path}"><img loading="lazy" src="{path}" '
                f'alt="{label}"></a><figcaption>{label}</figcaption></figure>')

    sections = ['<h2>District overview: flat / rejected / refined</h2>']
    for name in ["district-comparison-0.jpg", "district-comparison-6.jpg"]:
        sections.append(image(surface / name, "Left: original flat; middle: rejected Moth; right: refined Moth"))
    sections.append('<h2>Full-resolution matched districts</h2>')
    for district in stationary:
        sections.append(f'<h3>{html.escape(district.name)}</h3><div class="triple">')
        for variant in ["flat", "rejected", "refined"]:
            source = next(district.glob(f"*-{variant}-000.png"))
            sections.append(image(source, variant.title()))
        sections.append('</div>')
        for receipt in district.glob("*-refinement.json"):
            data = json.loads(receipt.read_text())
            if data.get("failures") != []:
                raise SystemExit(f"Failed native capture: {receipt}")
            sections.append(f'<p><a href="{copy(receipt)}">Camera, lighting and profile receipt</a></p>')
    sections.append('<h2>Matched moving-camera / grazing-light frames</h2><ul>')
    for district in districts:
        if district in stationary:
            continue
        for source in sorted(district.glob("*.png")):
            path = copy(source)
            sections.append(f'<li><a href="{path}">{html.escape(district.name + "/" + source.name)}</a></li>')
        for receipt in district.glob("*-refinement.json"):
            copy(receipt)
    sections.append('</ul><h2>All nine produced fighters: original / rejected / refined finishes</h2>')
    operators = sorted(production.glob("operator-compare-*.png"))
    if len(operators) != 9:
        raise SystemExit("Missing operator comparisons")
    for source in operators:
        sections.append(image(source, source.stem.removeprefix("operator-compare-")))
    sections.append('<h2>Paired-contact studies</h2>')
    sections.append(image(production / "pair-extremes-v2.jpg", "Meta/Qwen and Grok/Gemini: fixed-root contact studies; the combat core performs position swaps"))
    sections.append('<h2>Actual-stage combat clips — camera readability fix pending</h2>')
    videos = sorted(production.glob("gameplay-refined-*/motion.mp4"))
    if len(videos) != 5:
        raise SystemExit("Missing gameplay clips")
    for source in videos:
        path = copy(source)
        trace = copy(source.parent / "trace.json")
        sections.append(f'<h3>{html.escape(source.parent.name)}</h3><video controls preload="none" src="{path}"></video><p><a href="{trace}">Combat/FX trace</a></p>')
    for source in [surface / "input-identity.json", production / "HEAVY_GRANT_RELEASE.json"]:
        copy(source)
    document = '''<!doctype html><html lang="en"><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Native surface refinement and nine-fighter production B</title>
<style>body{margin:0 auto;padding:24px;max-width:1500px;background:#141922;color:#edf0f5;font:16px/1.5 system-ui}a{color:#9ed8ff}img,video{max-width:100%;height:auto}figure{margin:12px 0}figcaption{color:#bdcad6}.triple{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:10px}h2{margin-top:42px}.notice{border-left:4px solid #dcb767;padding:12px;background:#222833}@media(max-width:700px){.triple{grid-template-columns:1fr}}</style>
<h1>Native surface refinement &amp; nine-fighter production</h1>
<p>Retained Godot captures from production B, October 2, 2026. Images open at their original resolution. Files are copied byte-for-byte; no new render or video encoding.</p>
<p class="notice">Review candidate, not a published game release. Surfaces use matched proof lighting, which has not been verified against multiplayer production lighting. Software-rendered captures do not establish real-GPU performance. Foundry ceiling lights are too dull; the combat camera makes grounded fighters too small. Both have active follow-up owners. Operator finish differences are subtle in these side-lit views.</p>
<p><a href="../native-moth-review/">Earlier rejected Moth gallery</a> · <a href="manifest.json">SHA-256 inventory</a></p>
'''+"\n".join(sections)+"\n</html>\n"
    (destination / "index.html").write_text(document)
    manifest = {"production_source_commit": release["source_commit"],
                "grant": release["grant"], "files": records,
                "note": "Native retained evidence; pending presentation/art follow-up, not final release acceptance."}
    (destination / "manifest.json").write_text(json.dumps(manifest, indent=2)+"\n")
    print(json.dumps({"destination": str(destination), "files": len(records),
                      "bytes": sum(r["bytes"] for r in records)}))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("--destination", type=Path, required=True)
    args = parser.parse_args()
    publish(args.evidence.resolve(), args.destination.resolve())
