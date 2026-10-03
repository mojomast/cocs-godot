"""Publish an explicit retained-file inventory without rendering or encoding."""
import argparse
import hashlib
import html
import json
import shutil
from pathlib import Path


def publish(spec, destination):
    root = Path(spec["evidence_root"]).resolve()
    sources = []
    for item in spec["files"]:
        relative = Path(item["path"])
        source = (root / relative).resolve()
        if relative.is_absolute() or not source.is_relative_to(root) or not source.is_file():
            raise ValueError(f"Invalid/missing retained file: {relative}")
        if item["kind"] not in ["image", "video", "receipt"]:
            raise ValueError("Unknown file kind")
        sources.append((item, relative, source))
    if len({str(relative) for _, relative, _ in sources}) != len(sources):
        raise ValueError("Duplicate retained file")
    destination.mkdir(parents=True, exist_ok=False)
    records, sections = [], []
    for item, relative, source in sources:
        target = destination / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
        data = source.read_bytes()
        assert target.read_bytes() == data, f"Copy differs: {relative}"
        records.append({"path": relative.as_posix(), "bytes": len(data),
                        "sha256": hashlib.sha256(data).hexdigest()})
        path, caption = html.escape(relative.as_posix(), quote=True), html.escape(item["caption"])
        if item["kind"] == "image":
            sections.append(f'<figure><a href="{path}"><img loading="lazy" src="{path}" alt="{caption}"></a><figcaption>{caption}</figcaption></figure>')
        elif item["kind"] == "video":
            sections.append(f'<h2>{caption}</h2><video controls preload="none" src="{path}"></video>')
        else:
            sections.append(f'<p><a href="{path}">{caption}</a></p>')
    title = html.escape(spec["title"])
    body = f'''<!doctype html><html lang="en"><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1"><title>{title}</title>
<style>body{{max-width:1450px;margin:auto;padding:24px;background:#141922;color:#edf0f5;font:16px/1.5 system-ui}}a{{color:#9ed8ff}}img,video{{max-width:100%;height:auto}}figure{{margin:32px 0}}figcaption{{color:#bdcad6}}</style>
<h1>{title}</h1>'''
    body += "".join(f'<p>{html.escape(note)}</p>' for note in spec["notes"])
    body += '<p><a href="manifest.json">SHA-256 file inventory</a> · <a href="../">Earlier galleries</a></p>'
    (destination / "index.html").write_text(body + "\n".join(sections) + "\n</html>\n")
    manifest = {"source_commit": spec["source_commit"], "evidence_root": str(root),
                "files": records, "notes": spec["notes"]}
    (destination / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(json.dumps({"destination": str(destination), "files": len(records),
                      "bytes": sum(row["bytes"] for row in records)}))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--spec", type=Path, required=True)
    parser.add_argument("--destination", type=Path, required=True)
    args = parser.parse_args()
    publish(json.loads(args.spec.read_text()), args.destination.resolve())
