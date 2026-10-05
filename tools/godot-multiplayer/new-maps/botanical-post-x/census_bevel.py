"""Post-rebuild contact census for the Vesper stair bevel.

Answers one question, source-only: after the 2026-10-05 stair bevel rebuild, do
the pinned X contact positions still take a contact normal above the 46 degree
``floor_max_angle`` guard, and do the out-of-scope wall contacts persist?

Why a separate tool, rather than re-running ``diagnose_contacts.py``
``contacts-evidence.json`` is deliberately **not** regenerated.
That file is a frozen artifact of the native X-03 run: ``diagnose_contacts.py``
writes it with mode ``"x"`` so it can only ever be created once, and
``test_contacts.py``/``stair_clearance.py`` read it as the record of what the
engine reported. Regenerating it would silently replace the native record with a
reconstruction. This tool therefore reads that frozen evidence read-only and
re-derives the same per-contact distances against the **current** source
geometry, adding the two things the original census did not measure:

* the contact **normal angle** from ``Vector3.UP``, which is the quantity the
  ``response_guard.gd`` guard actually tests, and
* the bevel companion collider, unioned into its tread, because the capsule
  meets the chamfer and the flat top as one physical solid.

Authority (read-only): the frozen X-03 fixtures via ``fixture_inputs.x_bytes``,
and the two pinned source worlds via ``fixture_inputs.source``. Both accept the
reviewed rebuilt hashes. No engine, no Blender, no network; the only file written
is this tool's own evidence output.
"""
from __future__ import annotations

import json
import math
import sys
from pathlib import Path

from fixture_inputs import HERE, ROOT, SOURCE_PINS, X_PINS, x_bytes, source
sys.path.insert(0, str(HERE.parent / "botanical-correction"))
import diagnose_contacts as dc  # noqa: E402  (shares the capsule reconstruction)

EVIDENCE = HERE / "census-bevel-evidence.json"
# Read-only: the frozen record of what the native run reported.
FROZEN = HERE / "contacts-evidence.json"

# godot/exploration/walker.gd:21,35,37 -- the profile whose guard is at issue.
PROFILES = (
    {"label": "exploration r.35", "radius": 0.35, "height": 1.8, "separation": 0.0},
    # contacts-evidence.json originalCapsule -- radius .41 height 1.7, 5 cm lift.
    {"label": "x native r.41", "radius": 0.41, "height": 1.7, "separation": 0.05},
    # game/data.mjs:61 RULES -- radius .42 height 1.8, the test/game envelope.
    {"label": "game envelope r.42", "radius": 0.42, "height": 1.8, "separation": 0.0},
)
FLOOR_MAX_ANGLE_DEG = 46.0  # walker.gd floor_max_angle
TREAD_PREFIXES = ("civic-stair-", "roof-ramp-step-")
# Loaded in main() from the frozen evidence, read-only.
EVIDENCE_FROZEN: dict = {}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def point_triangle(p, tri):
    """Closest point on a triangle to ``p``, by the standard Voronoi regions."""
    a, b, c = tri
    ab = [b[i] - a[i] for i in range(3)]
    ac = [c[i] - a[i] for i in range(3)]
    ap = [p[i] - a[i] for i in range(3)]
    d1 = sum(ab[i] * ap[i] for i in range(3))
    d2 = sum(ac[i] * ap[i] for i in range(3))
    if d1 <= 0 and d2 <= 0:
        q = a
    else:
        bp = [p[i] - b[i] for i in range(3)]
        d3 = sum(ab[i] * bp[i] for i in range(3))
        d4 = sum(ac[i] * bp[i] for i in range(3))
        if d3 >= 0 and d4 <= d3:
            q = b
        else:
            vc = d1 * d4 - d3 * d2
            cp = [p[i] - c[i] for i in range(3)]
            d5 = sum(ab[i] * cp[i] for i in range(3))
            d6 = sum(ac[i] * cp[i] for i in range(3))
            if vc <= 0 and d1 >= 0 and d3 <= 0:
                t = d1 / (d1 - d3)
                q = [a[i] + ab[i] * t for i in range(3)]
            elif d6 >= 0 and d5 <= d6:
                q = c
            else:
                vb = d5 * d2 - d1 * d6
                if vb <= 0 and d2 >= 0 and d6 <= 0:
                    t = d2 / (d2 - d6)
                    q = [a[i] + ac[i] * t for i in range(3)]
                else:
                    va = d3 * d6 - d5 * d4
                    if va <= 0 and (d4 - d3) >= 0 and (d5 - d6) >= 0:
                        t = (d4 - d3) / ((d4 - d3) + (d5 - d6))
                        q = [b[i] + (c[i] - b[i]) * t for i in range(3)]
                    else:
                        den = 1.0 / (va + vb + vc)
                        q = [a[i] + ab[i] * (vb * den) + ac[i] * (vc * den) for i in range(3)]
    return math.dist(p, q), q


def deepest_contact(bottom, triangles):
    """Deepest sphere contact and the normal angle it presents, from UP.

    The normal is the direction from the nearest point on the collider to the
    capsule's bottom-sphere axis, which is the vector ``response_guard.gd``
    compares against ``cos(floor_max_angle)``.
    """
    best = None
    for tri in triangles:
        distance, point = point_triangle(bottom, tri)
        if best is None or distance < best[0]:
            best = (distance, point)
    require(best is not None, "a resolved contact must have geometry")
    distance, point = best
    separation = math.dist(bottom, point)
    if separation <= 1e-15:
        return {"distance": distance, "angle_deg": 0.0}
    vertical = (bottom[1] - point[1]) / separation
    return {"distance": distance, "angle_deg": math.degrees(math.acos(max(-1.0, min(1.0, vertical))))}


def bevel_companion(arena, collider_id):
    """The ``<id>-bevel`` chamfer surface paired with a tread, if present.

    The rebuild emits the 45 degree chamfer as a separate non-walkable surface so
    the walkable top keeps its id and triangle count. Physically the capsule meets
    both, so a census of "does this tread still present a >46 deg normal" has to
    consider them as one solid.
    """
    for surface in arena["terrain"]["surfaces"]:
        if surface["id"] == f"{collider_id}-bevel":
            return surface
    return None


def resolve_by_frozen_id(arena, collider_id):
    """Triangles of the collider the frozen evidence named, located by id.

    The native diagnostic identifies wall colliders only by the positional name
    ``OverheadSide<n>``, and ``WorldMap.build`` derives ``n`` from a running
    count of triangles emitted before it. The bevel adds 160 surface triangles, so
    every wall index shifts by 160 and the positional name now denotes a
    different wall. Resolving by the id the frozen evidence recorded instead
    keeps this census pinned to the *same physical collider* the engine hit,
    rather than silently re-pointing at whatever moved into that index.
    """
    if collider_id is None:
        return None
    for surface in arena["terrain"]["surfaces"]:
        if surface["id"] == collider_id:
            return [[surface["vertices"][i] for i in face] for face in surface["triangles"]]
    for wall in arena["terrain"]["walls"]:
        if wall.get("id") == collider_id:
            v = wall["vertices"]
            return [[v[0], v[i], v[i + 1]] for i in range(1, len(v) - 1)]
    return None


def build_report():
    """The census as a pure value; only ``main`` writes."""
    global EVIDENCE_FROZEN
    EVIDENCE_FROZEN = json.loads(FROZEN.read_text())
    native = json.loads(x_bytes(next(p for p in X_PINS if p.endswith("stair-diagnostic.json"))))
    physics = json.loads(x_bytes(next(p for p in X_PINS if p.endswith("physics-report.json"))))
    require(len(physics["errors"]) == 184, "pinned X physics report must still carry 184 errors")
    require(len(native["records"]) == 368, "pinned X stair diagnostic must still carry 368 records")

    worlds = {variant: source(variant)["arena"] for variant in SOURCE_PINS}
    colliders = {variant: dc.colliders(arena) for variant, arena in worlds.items()}
    surface_ids = {
        variant: {s["id"] for s in arena["terrain"]["surfaces"]}
        for variant, arena in worlds.items()
    }
    # The collider id the native run recorded, so a contact stays pinned to the
    # same physical body even where the positional collider name has shifted.
    frozen_ids = {
        (record["id"], name): contact["id"]
        for record in EVIDENCE_FROZEN["records"]
        for name, contact in ((c["nativeCollider"], c) for c in record["contacts"])
    }

    contacts = []
    for record in native["records"]:
        variant = "candidate" if record["candidate"] else "accepted"
        x, y, z = record["foot"]
        for name in record["contacts"]:
            collider = colliders[variant][name]
            frozen_id = frozen_ids.get((record["id"], name), collider["id"])
            is_tread = bool(frozen_id) and frozen_id.startswith(TREAD_PREFIXES)
            # Prefer the id-pinned geometry; fall back to the positional name only
            # when the frozen evidence recorded no id for this contact.
            triangles = resolve_by_frozen_id(worlds[variant], frozen_id) if frozen_id else None
            if triangles is None:
                triangles = collider["triangles"]
                frozen_id = collider["id"]
            if is_tread:
                chamfer = bevel_companion(worlds[variant], frozen_id)
                if chamfer is not None:
                    triangles = triangles + [[chamfer["vertices"][i] for i in face] for face in chamfer["triangles"]]
            entry = {"record": record["id"], "variant": variant, "nativeCollider": name,
                     "colliderId": frozen_id, "kind": "tread" if is_tread else "wall", "profiles": {}}
            for profile in PROFILES:
                bottom = [x, y + profile["separation"] + profile["radius"], z]
                contact = deepest_contact(bottom, triangles)
                contact["overlaps"] = contact["distance"] < profile["radius"] - 1e-7
                contact["over_floor_max_angle"] = contact["angle_deg"] > FLOOR_MAX_ANGLE_DEG
                entry["profiles"][profile["label"]] = contact
            contacts.append(entry)

    def summarize(entries, label):
        overlapping = [e for e in entries if e["profiles"][label]["overlaps"]]
        over = [e for e in overlapping if e["profiles"][label]["over_floor_max_angle"]]
        angles = [e["profiles"][label]["angle_deg"] for e in overlapping]
        return {
            "contacts": len(entries),
            "overlapping": len(overlapping),
            "overlapping_over_floor_max_angle": len(over),
            "cleared_floor_max_angle": len(overlapping) - len(over),
            "max_angle_deg": round(max(angles), 6) if angles else None,
            "min_angle_deg": round(min(angles), 6) if angles else None,
        }

    tread = [c for c in contacts if c["kind"] == "tread"]
    wall = [c for c in contacts if c["kind"] == "wall"]
    require(len(tread) == 354, f"expected 354 tread contacts, found {len(tread)}")
    require(len(wall) == 2, f"expected 2 non-tread contacts, found {len(wall)}")

    def run_of(contact):
        """Which stair run a tread contact belongs to, from its collider id."""
        if contact["colliderId"].startswith("civic-stair-"):
            return "civic"
        return "roof" if contact["colliderId"].startswith("roof-ramp-step-") else "other"

    # The accepted and candidate worlds are separate builds, and only the
    # accepted one was rebuilt, so the headline numbers are only meaningful once
    # split by variant. Reporting a merged total would credit the bevel with the
    # candidate run's result.
    by_variant = {}
    for variant in ("accepted", "candidate"):
        here = [c for c in contacts if c["variant"] == variant]
        by_variant[variant] = {
            "contacts": len(here),
            "treadContacts": sum(1 for c in here if c["kind"] == "tread"),
            "nonTreadContacts": sum(1 for c in here if c["kind"] == "wall"),
            "runs": {
                run: sum(1 for c in here if run_of(c) == run)
                for run in ("civic", "roof")
            },
            "profiles": {
                label: {
                    "tread": summarize([c for c in here if c["kind"] == "tread"], label),
                    "civic": summarize([c for c in here if run_of(c) == "civic"], label),
                    "roof": summarize([c for c in here if run_of(c) == "roof"], label),
                    "wall": summarize([c for c in here if c["kind"] == "wall"], label),
                }
                for label in (p["label"] for p in PROFILES)
            },
        }

    return {
        "scope": "source-only contact-normal census over the frozen X-03 records against the rebuilt Vesper source geometry; not a new native run",
        "rebuild": "VESPER_BEVEL_REBUILD_20261005.md",
        "frozenEvidence": "contacts-evidence.json is read-only; it records the native run and is never regenerated",
        "sourcePins": {v: list(p) for v, p in SOURCE_PINS.items()},
        "floorMaxAngleDeg": FLOOR_MAX_ANGLE_DEG,
        "records": len(native["records"]),
        "contactEntries": len(contacts),
        "treadAscensionEdgeContacts": len(tread),
        "nonTreadContacts": len(wall),
        "nonTreadColliders": sorted({c["colliderId"] for c in wall}),
        "nonTreadRecords": sorted({c["record"] for c in wall}),
        "profiles": {
            label: {
                "tread": summarize(tread, label),
                "wall": summarize(wall, label),
            }
            for label in (p["label"] for p in PROFILES)
        },
        "byVariant": by_variant,
        "isNativeClaim": False,
        "contacts": contacts,
    }


def main() -> int:
    report = build_report()
    with EVIDENCE.open("w") as handle:
        json.dump(report, handle, indent=2, allow_nan=False)
        handle.write("\n")

    exploration = report["profiles"]["exploration r.35"]
    print(
        f"{report['records']} records, {report['contactEntries']} contact entries: "
        f"{report['treadAscensionEdgeContacts']} tread ascent-edge + {report['nonTreadContacts']} non-tread"
    )
    for label, row in report["profiles"].items():
        print(
            f"{label:20s} all variants: tread {row['tread']['overlapping']:3d} overlapping, "
            f"{row['tread']['overlapping_over_floor_max_angle']:3d} over 46 deg "
            f"(max {row['tread']['max_angle_deg']})"
        )
    for variant, row in report["byVariant"].items():
        print(f"  {variant} ({row['contacts']} contacts: {row['treadContacts']} tread, {row['nonTreadContacts']} wall)")
        for label, profile in row["profiles"].items():
            print(
                f"    {label:20s} civic {profile['civic']['overlapping_over_floor_max_angle']:3d}/"
                f"{profile['civic']['overlapping']:3d} over 46 deg, "
                f"roof {profile['roof']['overlapping_over_floor_max_angle']:3d}/"
                f"{profile['roof']['overlapping']:3d}, "
                f"wall {profile['wall']['overlapping']}/{profile['wall']['contacts']}"
            )
    print(
        f"out-of-scope wall contacts persist: {exploration['wall']['overlapping']}/2 "
        f"at {report['nonTreadColliders']}"
    )
    print(f"wrote {EVIDENCE.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())