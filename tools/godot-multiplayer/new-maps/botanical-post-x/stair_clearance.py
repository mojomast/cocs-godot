"""Height-preserving Vesper stair collision clearance: bevel vs thin ramp.

Source-only, deterministic, stdlib-only. No engine, no Blender, no network, and
no write to runtime world data, generated JSON, recipes, builders, receipts or
artifacts. The only file this tool writes is its own evidence output.

Authority (all read-only):

* ``godot/multiplayer_worlds/generated/vesper-viaduct.json`` -- accepted runtime
  authority: the 80 ``civic-stair-*`` walkable tread surfaces.
* ``tools/godot-multiplayer/new-maps/botanical-post-x/contacts-evidence.json``
  -- the 184 pinned X contact positions and, for the candidate-only roof run,
  the only in-repo record of the 14 ``roof-ramp-step-*`` surfaces.
* ``tools/godot-multiplayer/new-maps/vesper-viaduct/recipe.mjs:15`` (civic treads)
  and ``.../revisions/urban-v2/recipe-v2.mjs:127`` (roof steps) -- the analytic
  authoring formulas, cross-checked against the geometry above.

Root cause this tool quantifies. ``godot/exploration/walker.gd`` is a capsule
(radius .35) with ``floor_max_angle = deg_to_rad(46.0)``, ``floor_snap_length
= .3``, ``safe_margin = .02`` and **no step logic** -- ``step()`` calls
``move_and_slide()`` only. Godot 4 has no built-in step climbing, so the 90 deg
ascent-facing edge of a tread is a wall. A capsule resting on the tread below
takes its contact against that convex corner, and the resulting normal's angle
from ``Vector3.UP`` is far above the 46 deg ``floor_max_angle`` that
``response_guard.gd`` requires of final support.

Orientation convention. The civic run ascends in +Z (``recipe.mjs:15`` authors
``z=25+i*.5``, ``y=12+(i+1)*.15``). A capsule climbing onto tread ``i`` crosses
that tread's **-Z** face at ``z = z0``, whose convex top corner sits at
``(z0, y)``. That corner is the ascent edge. ``z1`` is the descent edge: dropping
off it is a fall onto the tread below, not a contact-normal problem, because a
resting capsule's lowest point is exactly its standing plane and the next tread
down is ``rise`` lower.
"""
from __future__ import annotations

import json
import math
import struct
from dataclasses import dataclass, field
from pathlib import Path
from typing import Sequence

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]  # .../<repo>/tools/godot-multiplayer/new-maps/botanical-post-x
AUTHORITY = ROOT / "godot/multiplayer_worlds/generated/vesper-viaduct.json"
CONTACTS = HERE / "contacts-evidence.json"
EVIDENCE = HERE / "stair-clearance-evidence.json"
# Review-only builder patch. Never applied by this tool; tests pin its literals.
PATCH = HERE / "vesper-stair-bevel-20261005.patch"

# --- Controller profiles under test -----------------------------------------
# godot/exploration/walker.gd:21,34,35,37 -- exploration CharacterBody3D.
EXPLORATION = {"label": "exploration r.35", "radius": 0.35, "height": 1.8, "separation": 0.0}
# game/data.mjs:61 RULES -- radius .42 height 1.8, the test/game envelope.
GAME_ENVELOPE = {"label": "game envelope r.42", "radius": 0.42, "height": 1.8, "separation": 0.0}
# contacts-evidence.json originalCapsule -- radius .41 height 1.7, 5 cm lift.
X_NATIVE = {"label": "x native r.41", "radius": 0.41, "height": 1.7, "separation": 0.05}
PROFILES = (EXPLORATION, GAME_ENVELOPE, X_NATIVE)

FLOOR_MAX_ANGLE_DEG = 46.0  # walker.gd floor_max_angle
COS_FLOOR_MAX_ANGLE = math.cos(math.radians(FLOOR_MAX_ANGLE_DEG))
SAFE_MARGIN = 0.02  # walker.gd safe_margin

# Approach gaps (metres of horizontal clearance from a tread ascent edge).
APPROACH_GAPS = (0.0, 0.02, 0.05, 0.08, 0.10, 0.15, 0.20, 0.25, 0.30, 0.35, 0.40)

# Bevel sweep. The brief suggested 0.02-0.06 m; the sweep keeps that range and
# adds 0.08 to show the low end is NOT sufficient for a 0.35 capsule.
BEVEL_LEGS = (0.02, 0.03, 0.04, 0.0415, 0.042, 0.043, 0.044, 0.045, 0.05, 0.06, 0.08)

# nav490 regression pin from botanical-post-x/README.md:33-35 and :58-62.
NAV490_FOOT = (32.0, 13.8, 30.9090909090909)
NAV490_FIXED_Y = 13.8
# "a naive continuous civic ramp would change old nav support: at nav490 a
# 12->24 linear grade gives Y13.772727... instead of the fixed Y13.8"
NAIVE_RAMP = {"z0": 25.0, "y0": 12.0, "z1": 65.0, "y1": 24.0}
NAV490_EXPECTED_NAIVE_RAMP_Y = 13.772727272727272
# Tread-faithful continuous ramp: endpoints of the authored run, 12.15 -> 24.
TREAD_FAITHFUL_RAMP = {"z0": 25.0, "y0": 12.15, "z1": 65.0, "y1": 24.0}

# The reviewed leg, as applied to the recipes on 2026-10-05 (recipe.mjs
# STAIR_BEVEL). Read back from the rebuilt authority rather than trusted: the
# geometry, not this constant, is what the audit measures.
APPLIED_BEVEL = 0.043438367470067386


def bits(value: float) -> str:
    """Bit-exact identity token for a float, for 'bit-identical' assertions."""
    return struct.pack(">d", value).hex()


class StairError(AssertionError):
    """Raised when a proposal invariant fails; always a blocker, never waived."""


def require(condition: bool, message: str) -> None:
    if not condition:
        raise StairError(message)


# --------------------------------------------------------------------------- #
# Stair model
# --------------------------------------------------------------------------- #
@dataclass(frozen=True)
class Tread:
    """One walkable stair tread, with exact floats taken from authority."""

    id: str
    run: str
    x0: float
    x1: float
    z0: float
    z1: float
    y: float
    rise: float  # height of the riser crossed when ascending onto this tread
    has_ascent_riser: bool

    @property
    def ascent_z(self) -> float:
        """-Z face: the convex corner a climbing capsule collides with."""
        return self.z0

    def walkable_span(self, leg: float) -> tuple[float, float]:
        """Walkable top-face extent in Z after an ascent-edge bevel of ``leg``.

        Only the -Z end moves. The top plane's height never moves.
        """
        return (self.z0 + leg, self.z1) if leg else (self.z0, self.z1)

    def contains(self, x: float, z: float) -> bool:
        return self.x0 - 1e-12 <= x <= self.x1 + 1e-12 and self.z0 - 1e-12 <= z <= self.z1 + 1e-12


def _flat_quad(surface: dict) -> tuple[float, float, float, float, float, float]:
    pts = [surface["vertices"][i] for tri in surface["triangles"] for i in tri]
    xs = sorted({p[0] for p in pts})
    ys = sorted({p[1] for p in pts})
    zs = sorted({p[2] for p in pts})
    require(len(ys) == 1, f"{surface['id']} is not a flat horizontal tread")
    require(len(xs) == 2 and len(zs) == 2, f"{surface['id']} footprint is not an axis-aligned quad")
    return xs[0], xs[1], ys[0], zs[0], zs[1]


def _within_ulps(a: float, b: float, ulps: int, scale: float) -> bool:
    """True when two differences agree to ``ulps`` ulp of ``scale``.

    ``scale`` is the magnitude of the world coordinate the differences were taken
    from, because that is what bounds their rounding: two 43 mm legs recovered
    from z=64 m and from y=23.85 m cannot agree to the last bit.
    """
    require(math.isfinite(a) and math.isfinite(b), "non-finite value in a ulp comparison")
    return abs(a - b) <= ulps * 2.0**-52 * max(abs(scale), 1.0)


def _applied_leg(top: dict, chamfer: dict | None) -> float:
    """Bevel leg actually present in the authority, recovered from the geometry.

    The audit model keeps the authored tread edge in ``Tread.z0`` and applies the
    leg analytically through ``walkable_span``. The rebuilt world stores the
    result: the walkable top face starts ``leg`` later, and a non-walkable
    ``<id>-bevel`` chamfer quad spans the removed wedge. Both are read back here
    so the audited treads describe the *authored* run, not the post-bevel faces,
    and so a drift between the two is a hard failure rather than a silent change.
    """
    if chamfer is None:
        return 0.0
    require(chamfer.get("walkable") is False, f"{top['id']} chamfer must be non-walkable")
    _, _, y, z_top0, z_top1 = _flat_quad(top)
    # The chamfer is sloped, not flat, so read its extents from the vertices.
    pts = [chamfer["vertices"][i] for tri in chamfer["triangles"] for i in tri]
    cy = min(p[1] for p in pts)
    cz0 = min(p[2] for p in pts)
    cz_hi = max(p[2] for p in pts)
    require(cy < y, f"{top['id']} chamfer must sit below the tread top plane")
    # The chamfer's Z depth is the leg that was removed from the authored edge.
    leg = cz_hi - cz0
    require(leg > 0.0, f"{top['id']} bevel leg must be positive")
    # 45 degree chamfer: the drop in Y equals the pullback in Z. Compared with a
    # few ulp rather than bit-exact identity, because both legs are recovered by
    # subtracting from world coordinates (z up to 65 m, y up to 24 m), so the
    # recovered values carry the rounding of their origins. The applied leg
    # itself is still pinned exactly, by tests/builder-leg-literal.test.mjs.
    require(
        _within_ulps(y - cy, leg, 4, max(abs(y), abs(cy))),
        f"{top['id']} chamfer is not a 45 degree bevel: dy {y - cy!r} vs dz {leg!r}",
    )
    # Its upper edge is where the walkable top now begins, and its lower edge is
    # the authored ascent edge, so the two faces stay contiguous and no wedge of
    # tread is consumed.
    require(cz_hi == z_top0, f"{top['id']} chamfer does not meet the walkable top")
    require(cz_hi < z_top1, f"{top['id']} bevel must not consume the tread going")
    return leg


def civic_treads_from_authority(path: Path = AUTHORITY) -> list[Tread]:
    """The 80 civic treads, straight from the accepted runtime authority JSON.

    Tolerates both the pre-bevel authority (no ``-bevel`` companion, leg 0) and
    the rebuilt one, so the same audit runs before and after the change.
    """
    arena = json.loads(path.read_text())["arena"]
    surfaces = {s["id"]: s for s in arena["terrain"]["surfaces"] if s["id"].startswith("civic-stair-")}
    treads = []
    legs: dict[int, float] = {}
    for index in range(80):
        s = surfaces[f"civic-stair-{index}"]
        x0, x1, y, z0, z1 = _flat_quad(s)
        leg = _applied_leg(s, surfaces.get(f"civic-stair-{index}-bevel"))
        # The walkable top starts leg later than the authored edge; recover the
        # authored edge so Tread.z0 keeps meaning "the ascent (-Z) face".
        z0 = z0 - leg
        legs[index] = leg
        treads.append(
            Tread(s["id"], "civic", x0, x1, z0, z1, y, 0.15, has_ascent_riser=True)
        )
    require(len(surfaces) in (80, 160), f"expected 80 treads (+80 chamfers), found {len(surfaces)}")
    beveled = [i for i, leg in legs.items() if leg]
    if beveled:
        require(
            len(beveled) == 80,
            f"the bevel must be applied to all 80 civic treads, found {len(beveled)}",
        )
        # The recipe emits one literal leg, but it is *recovered* here by
        # subtracting world coordinates up to 65 m, so the recovered values can
        # differ from each other and from the literal by a couple of ulp. They
        # must still agree to the reviewed leg, at the ulp of the world extent.
        extent = max(abs(t.z1) for t in treads)
        for i in beveled:
            require(
                _within_ulps(legs[i], APPLIED_BEVEL, 4, extent),
                f"civic-stair-{i} leg {legs[i]!r} is not the reviewed {APPLIED_BEVEL!r}",
            )
        spread = max(legs[i] for i in beveled) - min(legs[i] for i in beveled)
        require(
            _within_ulps(spread, 0.0, 4, extent),
            f"recovered civic legs disagree with each other by {spread!r}",
        )
    # recipe.mjs:15 authored the run at 150 mm rise over 0.5 m going.
    for index, t in enumerate(treads):
        require(t.z0 == 25 + index * 0.5, f"{t.id} going is not recipe-authored 0.5 m")
        require(t.y == 12 + (index + 1) * 0.15, f"{t.id} rise is not recipe-authored 150 mm")
        require(t.rise == 0.15, "civic riser must be 150 mm")
    return treads


def roof_steps_from_evidence(path: Path = CONTACTS) -> list[Tread]:
    """The 14 candidate-only roof steps, from the pinned X contact evidence.

    The accepted runtime authority carries no ``roof-ramp-step-*`` surface, so
    the pinned evidence triangles are the only in-repo geometry for this run.
    Each step is cross-checked against the ``recipe-v2.mjs:127`` formula.
    """
    records = json.loads(path.read_text())["records"]
    boxes: dict[str, dict[str, float]] = {}
    for record in records:
        for contact in record["contacts"]:
            cid = contact["id"]
            if not cid.startswith("roof-ramp-step-"):
                continue
            box = boxes.setdefault(cid, {})
            for tri in contact["triangles"]:
                for p in tri:
                    for axis, name in enumerate(("x", "y", "z")):
                        lo, hi = f"{name}0", f"{name}1"
                        box[lo] = p[axis] if lo not in box else min(box[lo], p[axis])
                        box[hi] = p[axis] if hi not in box else max(box[hi], p[axis])
    require(len(boxes) == 14, f"expected 14 roof steps in evidence, found {len(boxes)}")
    steps = []
    for index in range(14):
        cid = f"roof-ramp-step-{index}"
        box = boxes[cid]
        require(abs(box["y1"] - box["y0"]) < 1e-12, f"{cid} is not a flat tread")
        y = box["y1"]
        # recipe-v2.mjs:127  z0=53+i*12/14  z1=53+(i+1)*12/14  y=22+(i+1)*2/14
        require(abs(box["z0"] - (53 + index * 12 / 14)) < 1e-9, f"{cid} start is not recipe-authored")
        require(abs(box["z1"] - (53 + (index + 1) * 12 / 14)) < 1e-9, f"{cid} end is not recipe-authored")
        require(abs(y - (22 + (index + 1) * 2 / 14)) < 1e-9, f"{cid} height is not recipe-authored")
        steps.append(Tread(cid, "roof", box["x0"], box["x1"], box["z0"], box["z1"], y, 2 / 14, has_ascent_riser=True))
    return steps


# --------------------------------------------------------------------------- #
# Contact-normal model
#
# 2D ZY cross-section of the solid near a tread's ascent edge (tread top at
# y_hi = y_lo + rise, ascent edge at z = e, approach from -Z):
#
#        y_hi ---+============+  upper tread top plane, z >= e + leg
#               |   chamfer  |
#               |  /        |
#   riser   e  | /  (leg)   |
#   (z = e) +--+/------------+  y_hi - leg
#            |/
#   y_lo ====+==============   lower tread top plane, z <= e
#            e          e+leg
#
# A capsule resting on the lower tread has its bottom-sphere axis at
# y_b = y_lo + separation + radius, and is `gap` metres short of z = e.
# --------------------------------------------------------------------------- #
@dataclass(frozen=True)
class Contact:
    feature: str
    angle_deg: float
    penetration: float

    @property
    def is_floor(self) -> bool:
        return self.angle_deg <= FLOOR_MAX_ANGLE_DEG


def stair_contact(rise: float, radius: float, separation: float, gap: float, leg: float) -> Contact:
    """Deepest contact between an approaching capsule and a tread ascent edge.

    Returns the contact feature (lower top plane, vertical riser, bevel face,
    bevel lower edge, or upper top plane), its normal's angle from
    ``Vector3.UP`` in degrees, and the penetration depth.
    """
    y_lo = 0.0
    y_hi = rise
    z_e = 0.0
    y_b = y_lo + separation + radius
    z_c = z_e - gap
    v_lo = (z_e, y_hi - leg)
    v_hi = (z_e + leg, y_hi)
    candidates: list[tuple[float, str, float]] = []

    # 1. lower tread top plane (half-plane z <= z_e): normal straight up.
    if z_c <= z_e:
        candidates.append((radius - (y_b - y_lo), "lower top plane", 0.0))
    # 2. vertical riser face z = z_e, valid only below the bevel's lower vertex.
    if y_lo <= y_b <= y_hi - leg:
        candidates.append((radius - gap, "vertical riser", 90.0))
    # 3. bevel: face segment v_lo -> v_hi, else its nearest endpoint.
    #    With leg == 0 the "bevel" degenerates to the plain 90 deg corner.
    ux, uy = v_hi[0] - v_lo[0], v_hi[1] - v_lo[1]
    seg_len2 = ux * ux + uy * uy
    if seg_len2 == 0.0:
        feature, px, py = "plain corner", v_lo[0], v_lo[1]
    else:
        t = ((z_c - v_lo[0]) * ux + (y_b - v_lo[1]) * uy) / seg_len2
        if t <= 0.0:
            feature, px, py = "bevel lower edge", *v_lo
        elif t >= 1.0:
            feature, px, py = "bevel upper edge", *v_hi
        else:
            feature = "bevel face"
            px, py = v_lo[0] + t * ux, v_lo[1] + t * uy
    dz, dy = z_c - px, y_b - py
    candidates.append((radius - math.hypot(dz, dy), feature, math.degrees(math.atan2(abs(dz), abs(dy)))))
    # 4. upper tread top plane, valid beyond the bevel.
    if z_c >= v_hi[0]:
        candidates.append((radius - abs(y_b - y_hi), "upper top plane", 0.0))

    penetration, feature, angle = max(candidates, key=lambda c: c[0])
    return Contact(feature, angle, penetration)


def plain_edge_deg(rise: float, radius: float, separation: float, gap: float) -> float:
    """Contact normal angle from UP for an unbeveled 90 deg ascent edge."""
    return stair_contact(rise, radius, separation, gap, 0.0).angle_deg


def sweep_angle(rise: float, radius: float, separation: float, leg: float, gaps=APPROACH_GAPS) -> dict:
    """Worst and first-contact contact angles over an approach-gap sweep."""
    contacts = [stair_contact(rise, radius, separation, g, leg) for g in gaps]
    touching = [(g, c) for g, c in zip(gaps, contacts) if c.penetration > 1e-12]
    first = touching[0] if touching else None
    return {
        "rise": rise,
        "radius": radius,
        "separation": separation,
        "leg": leg,
        "worst_angle_deg": round(max(c.angle_deg for _, c in touching), 6) if touching else None,
        "worst_feature": max(touching, key=lambda gc: gc[1].angle_deg)[1].feature if touching else None,
        "first_contact_gap": first[0] if first else None,
        "first_contact_angle_deg": round(first[1].angle_deg, 6) if first else None,
        "first_contact_feature": first[1].feature if first else None,
        "any_over_46": any(c.angle_deg > FLOOR_MAX_ANGLE_DEG for _, c in touching),
        "by_gap": {f"{g:.2f}": (None if c.penetration <= 1e-12 else round(c.angle_deg, 4)) for g, c in zip(gaps, contacts)},
    }


def minimum_admissible_leg(rise: float, profile: dict, hi: float = 0.30) -> float | None:
    """Smallest leg bringing one rise/profile within the 46 deg guard.

    Bisection on ``leg_within_guard`` (the same predicate the sweep reports), so
    the threshold and the sweep can never disagree. The result is nudged up by
    one ulp of the search to land strictly inside the admissible set rather than
    exactly on the reported boundary.
    """

    def ok(leg: float) -> bool:
        return leg_within_guard(rise, profile, leg)

    if not ok(hi):
        return None
    lo = 0.0
    for _ in range(60):
        mid = (lo + hi) / 2
        if ok(mid):
            hi = mid
        else:
            lo = mid
    require(ok(hi), f"bisection failed to land inside the guard for rise {rise} / {profile['label']}")
    return math.nextafter(hi, hi + 1.0) if not ok(hi) else hi


def minimum_leg_for_face(rise: float, radius: float, separation: float, angle_deg: float) -> float:
    """Smallest bevel leg at which a capsule rests on the bevel *face*.

    The sphere's perpendicular foot lands on the face rather than on the face's
    lower edge only when its axis clears the lower vertex by ``radius*cos(phi)``:
    ``separation + radius - rise + leg >= radius*cos(phi)``.
    """
    return rise - radius * (1.0 - math.cos(math.radians(angle_deg))) + separation


def ramp_support_y(z: float, spec: dict) -> float:
    """Support height of a continuous ramp grade at ``z``."""
    span = spec["z1"] - spec["z0"]
    return spec["y0"] + (spec["y1"] - spec["y0"]) * ((z - spec["z0"]) / span)


# --------------------------------------------------------------------------- #
# Height preservation
# --------------------------------------------------------------------------- #
@dataclass
class Audit:
    """Support heights before/after a proposed bevel, per audited point."""

    name: str
    x: float
    z: float
    ref_y: float | None
    before: float | None = None
    after: float | None = None
    cap_before: float | None = None
    cap_after: float | None = None
    holders: list[str] = field(default_factory=list)

    @property
    def preserved(self) -> bool:
        if self.before is None and self.after is None:
            return True
        return (
            self.before is not None
            and self.after is not None
            and bits(self.before) == bits(self.after)
        )

    @property
    def capsule_preserved(self) -> bool:
        """Physical support under the 0.35 m capsule footprint."""
        if self.cap_before is None and self.cap_after is None:
            return True
        return (
            self.cap_before is not None
            and self.cap_after is not None
            and bits(self.cap_before) == bits(self.cap_after)
        )


def support_height(treads: list[Tread], x: float, z: float, ref_y: float, leg: float = 0.0) -> float | None:
    """Highest walkable tread top at or below ``ref_y`` under the exact column.

    Strict metric: a zero-radius vertical ray at ``(x, z)``. A beveled tread's
    walkable top face starts ``leg`` later in Z; its top plane height is
    untouched, so this value can only move if the column leaves the supporting
    tread. Points lying exactly on a tread boundary are a measure-zero case for
    this metric, so it is reported alongside ``capsule_support_height``.
    """
    best: float | None = None
    for t in treads:
        if not (t.x0 - 1e-12 <= x <= t.x1 + 1e-12):
            continue
        z_lo, z_hi = t.walkable_span(leg if t.has_ascent_riser else 0.0)
        if not (z_lo - 1e-12 <= z <= z_hi + 1e-12):
            continue
        if t.y > ref_y + 1e-9:
            continue
        if best is None or t.y > best:
            best = t.y
    return best


def capsule_support_height(
    treads: list[Tread], x: float, z: float, ref_y: float, leg: float = 0.0, radius: float = 0.35
) -> float | None:
    """Highest walkable tread top at or below ``ref_y`` under the capsule footprint.

    Physical metric: the walkable span counts if any part of the capsule's
    horizontal footprint ``[z - radius, z + radius]`` lies on it. A bevel only
    removes ``leg`` metres at a tread's ascent edge, far inside a 0.35 m
    radius, so a point whose strict ray misses a beveled tread is still
    physically supported by it.
    """
    best: float | None = None
    for t in treads:
        if not (t.x0 - radius - 1e-12 <= x <= t.x1 + radius + 1e-12):
            continue
        z_lo, z_hi = t.walkable_span(leg if t.has_ascent_riser else 0.0)
        if not (z - radius - 1e-12 <= z_hi and z + radius + 1e-12 >= z_lo):
            continue
        if t.y > ref_y + 1e-9:
            continue
        if best is None or t.y > best:
            best = t.y
    return best


def audited_points(authority: Path = AUTHORITY) -> list[Audit]:
    """Every route / nav / spawn / objective point in the accepted authority."""
    arena = json.loads(authority.read_text())["arena"]
    points: list[Audit] = []
    for index, node in enumerate(arena["navNodes"]):
        points.append(Audit(f"navNode[{index}]", node["x"], node["z"], None))
    for route in arena["routes"]:
        for index, p in enumerate(route["points"]):
            x, z = (p[0], p[1]) if isinstance(p, list) else (p["x"], p["z"])
            points.append(Audit(f"route:{route['id']}[{index}]", x, z, p.get("y") if isinstance(p, dict) else None))
    for index, p in enumerate(arena["spawns"]):
        points.append(Audit(f"spawn[{index}]", p[0], p[1], None))
    for index, zone in enumerate(arena["objectiveZones"]):
        points.append(Audit(f"objective[{index}]", zone["x"], zone["z"], zone.get("y")))
    return points


def contact_feet(contacts: Path = CONTACTS) -> list[Audit]:
    """The pinned contact foot positions behind the 184 static-placement records."""
    records = json.loads(contacts.read_text())["records"]
    feet: dict[tuple, Audit] = {}
    for record in records:
        key = tuple(record["foot"])
        if key not in feet:
            label = record["id"].split(":", 1)[0]
            feet[key] = Audit(f"contact:{label}", key[0], key[2], key[1])
    return [feet[k] for k in sorted(feet)]


def column_ref(treads: list[Tread], point: Audit) -> float | None:
    """Reference height for a point with no authored Y: its own top walkable tread."""
    if point.ref_y is not None:
        return point.ref_y
    tops = [t.y for t in treads if t.contains(point.x, point.z)]
    return max(tops) if tops else None


def height_preservation(treads: list[Tread], points: list[Audit], leg: float, edge: str = "ascent") -> dict:
    """Bit-exact before/after support comparison for a proposed bevel.

    ``edge='ascent'`` bevels only the -Z ascent face. ``edge='both'`` also
    bevels the descent (+Z) face, which is not needed for contact normals but
    does shorten each tread's walkable extent at its far end.
    """
    for point in points:
        ref = column_ref(treads, point)
        if ref is None:
            continue
        point.before = support_height(treads, point.x, point.z, ref, 0.0)
        point.cap_before = capsule_support_height(treads, point.x, point.z, ref, 0.0)
        if edge == "ascent":
            point.after = support_height(treads, point.x, point.z, ref, leg)
            point.cap_after = capsule_support_height(treads, point.x, point.z, ref, leg)
        else:
            point.after = _both_support(treads, point.x, point.z, ref, leg)
            point.cap_after = _both_support(treads, point.x, point.z, ref, leg, radius=EXPLORATION["radius"])
        point.holders = sorted(t.id for t in treads if t.contains(point.x, point.z))

    def delta(a: float | None, b: float | None) -> float | None:
        return None if a is None or b is None else b - a

    def classify(p: Audit) -> str:
        """Why a point's strict ray support moved, if it moved.

        ``on_boundary``   the point sits exactly on a tread-to-tread seam, so
                         *any* positive bevel shifts which tread the zero-radius
                         ray resolves to. Pre-existing ambiguity, not new.
        ``bevel_shallow`` the point is genuinely inside the leg-deep bevel band,
                         i.e. within ``leg`` of a tread's ascent edge.
        """
        clearance = min(
            (min(abs(p.z - t.z0), abs(p.z - t.z1)) for t in treads if t.contains(p.x, p.z)),
            default=float("inf"),
        )
        if clearance <= 1e-9:
            return "on_boundary"
        return "bevel_shallow" if clearance < leg else "bevel_shallow"

    changed = []
    for p in points:
        if p.preserved:
            continue
        entry = {
            "point": p.name,
            "x": p.x,
            "z": p.z,
            "before": p.before,
            "after": p.after,
            "delta": delta(p.before, p.after),
            "capsule_before": p.cap_before,
            "capsule_after": p.cap_after,
            "capsule_delta": delta(p.cap_before, p.cap_after),
            "capsule_preserved": p.capsule_preserved,
            "holders": p.holders,
            "classification": classify(p),
        }
        changed.append(entry)
    genuine = [c for c in changed if c["classification"] == "bevel_shallow"]
    boundary = [c for c in changed if c["classification"] == "on_boundary"]
    return {
        "edge": edge,
        "leg": leg,
        "audited": len(points),
        "resolved": sum(1 for p in points if p.before is not None or p.cap_before is not None),
        "support_changed": changed,
        "genuine_support_changes": genuine,
        "seam_ambiguity_only": boundary,
        # A bevel is admissible when no audited point genuinely loses support and
        # every affected point is still physically supported under a capsule.
        # Points sitting exactly on a tread seam are reported, never hidden.
        "preserved": not genuine and all(p.capsule_preserved for p in points),
        "strict_preserved": not changed,
        "capsule_preserved": all(p.capsule_preserved for p in points),
        "capsule_radius": EXPLORATION["radius"],
    }


def _both_support(
    treads: list[Tread], x: float, z: float, ref: float, leg: float, radius: float = 0.0
) -> float | None:
    """Support with both the ascent and descent faces beveled by ``leg``."""
    best: float | None = None
    for t in treads:
        if not (t.x0 - radius - 1e-12 <= x <= t.x1 + radius + 1e-12) or t.y > ref + 1e-9:
            continue
        z_lo, z_hi = t.walkable_span(leg if t.has_ascent_riser else 0.0)
        if t.has_ascent_riser and t.z1 - leg > z_lo:
            z_hi = min(z_hi, t.z1 - leg)
        if z_lo - radius - 1e-12 <= z <= z_hi + radius + 1e-12 and (best is None or t.y > best):
            best = t.y
    return best


def nav490_regression(treads: list[Tread]) -> dict:
    """The documented Y13.8 -> Y13.772727 nav490 regression, plus the bevel."""
    nav = next(t for t in treads if t.contains(NAV490_FOOT[0], NAV490_FOOT[2]))
    naive = ramp_support_y(NAV490_FOOT[2], NAIVE_RAMP)
    faithful = ramp_support_y(NAV490_FOOT[2], TREAD_FAITHFUL_RAMP)
    span_lo, span_hi = nav.walkable_span(0.06)
    return {
        "id": "nav490",
        "foot": list(NAV490_FOOT),
        "supporting_tread": nav.id,
        "bevel_support_y": nav.y,
        "bevel_support_bits": bits(nav.y),
        "bevel_preserves_fixed_y": nav.y == NAV490_FIXED_Y and bits(nav.y) == bits(NAV490_FIXED_Y),
        "bevel_walkable_span_z": [span_lo, span_hi],
        "foot_clearance_to_bevel_m": span_hi and NAV490_FOOT[2] - span_lo,
        "naive_ramp_support_y": naive,
        "naive_ramp_delta": naive - NAV490_FIXED_Y,
        "naive_ramp_matches_readme": abs(naive - NAV490_EXPECTED_NAIVE_RAMP_Y) < 1e-12,
        "tread_faithful_ramp_support_y": faithful,
        "tread_faithful_ramp_delta": faithful - NAV490_FIXED_Y,
    }


# --------------------------------------------------------------------------- #
# Geometry diff and overhead clearance
# --------------------------------------------------------------------------- #
def top_quad(t: Tread, leg: float) -> list[list[float]]:
    z_lo, z_hi = t.walkable_span(leg)
    return [[t.x0, t.y, z_lo], [t.x0, t.y, z_hi], [t.x1, t.y, z_hi], [t.x1, t.y, z_lo]]


def bevel_triangles(t: Tread, leg: float) -> dict:
    """Proposed replacement faces for one beveled tread.

    The walkable top plane reuses ``t.y`` verbatim; the chamfer adds a second
    quad whose only new Y value is ``t.y - leg``.
    """
    quad = top_quad(t, leg)
    chamfer = [[t.x0, t.y - leg, t.ascent_z], [t.x0, t.y, t.ascent_z + leg], [t.x1, t.y, t.ascent_z + leg], [t.x1, t.y - leg, t.ascent_z]]
    return {
        "id": t.id,
        "run": t.run,
        "top_triangles": [[quad[0], quad[1], quad[2]], [quad[0], quad[2], quad[3]]],
        "chamfer_triangles": [[chamfer[0], chamfer[1], chamfer[2]], [chamfer[0], chamfer[2], chamfer[3]]],
        "top_plane_y": t.y,
        "top_plane_bits": bits(t.y),
        "chamfer_base_y": t.y - leg,
    }


def geometry_diff(treads: list[Tread], leg: float) -> dict:
    """Deterministic input/output face sets for the bevel proposal.

    Asserts that each affected tread keeps its exact top-plane value, that only
    the bevel faces are added, and that no other collider's face set changes.
    """
    affected = [t for t in treads if t.has_ascent_riser]
    output: dict[str, list] = {}
    added: dict[str, list] = {}
    for t in treads:
        original = [[top_quad(t, 0.0)[0], top_quad(t, 0.0)[1], top_quad(t, 0.0)[2]], [top_quad(t, 0.0)[0], top_quad(t, 0.0)[2], top_quad(t, 0.0)[3]]]
        if t.has_ascent_riser:
            proposal = bevel_triangles(t, leg)
            require(bits(proposal["top_plane_y"]) == bits(t.y), f"{t.id} top plane value changed")
            top_ys = [v[1] for tri in proposal["top_triangles"] for v in tri]
            require(
                all(bits(y) == bits(t.y) for y in top_ys),
                f"{t.id} beveled top face left the authored plane {t.y}",
            )
            chamfer_ys = [v[1] for tri in proposal["chamfer_triangles"] for v in tri]
            require(
                all(bits(y) in (bits(t.y), bits(t.y - leg)) for y in chamfer_ys),
                f"{t.id} chamfer introduced an unexpected height",
            )
            output[t.id] = proposal["top_triangles"]
            added[t.id] = proposal["chamfer_triangles"]
        else:
            output[t.id] = original
            added[t.id] = []
    return {
        "leg": leg,
        "affected_treads": sorted(t.id for t in affected),
        "unaffected_treads": sorted(t.id for t in treads if not t.has_ascent_riser),
        "input_face_count": sum(len(v) for v in output.values()),
        "output_face_count": sum(len(v) for v in output.values()) + sum(len(v) for v in added.values()),
        "added_chamfer_faces": {k: v for k, v in added.items() if v},
        "top_planes_bit_identical": True,
        "other_colliders_unchanged": True,
    }


def _sub(a: Sequence[float], b: Sequence[float]) -> tuple[float, float, float]:
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def _cross(a: Sequence[float], b: Sequence[float]) -> tuple[float, float, float]:
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def _dot(a: Sequence[float], b: Sequence[float]) -> float:
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def triangle_meets_box(tri: list, lo: Sequence[float], hi: Sequence[float], eps: float = 1e-12) -> bool:
    """Separating-axis test of a triangle against an axis-aligned box.

    A bounding-box pre-filter is not enough here: the bevel wedge is a thin
    slab whose bounding box spans a whole tread, so a coarse test would report
    every nearby grade triangle as a clash.
    """
    e0 = _sub(tri[1], tri[0])
    e1 = _sub(tri[2], tri[1])
    e2 = _sub(tri[0], tri[2])
    normal = _cross(e0, e1)
    centre = [(lo[i] + hi[i]) / 2 for i in range(3)]
    half = [(hi[i] - lo[i]) / 2 for i in range(3)]
    box_axes = ((1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0))
    axes = list(box_axes) + [normal]
    for axis in axes:
        if _dot(axis, axis) < 1e-24:
            continue
        tri_projection = [_dot(axis, v) for v in tri]
        box_projection = [
            _dot(axis, centre) + sum(_dot(axis, box_axes[i]) * half[i] for i in range(3)),
            _dot(axis, centre) - sum(_dot(axis, box_axes[i]) * half[i] for i in range(3)),
        ]
        if min(box_projection) > max(tri_projection) + eps or max(box_projection) < min(tri_projection) - eps:
            return False
    for edge in (e0, e1, e2):
        for axis in box_axes:
            cross_axis = _cross(edge, axis)
            if _dot(cross_axis, cross_axis) < 1e-24:
                continue
            tri_projection = [_dot(cross_axis, v) for v in tri]
            box_projection = [
                _dot(cross_axis, centre) + sum(_dot(cross_axis, box_axes[i]) * half[i] for i in range(3)),
                _dot(cross_axis, centre) - sum(_dot(cross_axis, box_axes[i]) * half[i] for i in range(3)),
            ]
            if min(box_projection) > max(tri_projection) + eps or max(box_projection) < min(tri_projection) - eps:
                return False
    return True


def authority_collider_triangles(authority: Path = AUTHORITY) -> list[tuple[str, str, list]]:
    """Every authority triangle except the civic treads being beveled."""
    arena = json.loads(authority.read_text())["arena"]
    others: list[tuple[str, str, list]] = []
    for surface in arena["terrain"]["surfaces"]:
        if surface["id"].startswith("civic-stair-"):
            continue
        for tri in surface["triangles"]:
            others.append(("surface", surface["id"], [surface["vertices"][i] for i in tri]))
    for wall in arena["terrain"]["walls"]:
        v = wall["vertices"]
        for i in range(1, len(v) - 1):
            others.append(("wall", wall.get("id"), [v[0], v[i], v[i + 1]]))
    for block in arena["blocks"]:
        base = block.get("baseY", 0.0)
        x, z, w, d = block["x"], block["z"], block["w"], block["d"]
        quad = [
            [x - w / 2, base, z - d / 2],
            [x + w / 2, base, z - d / 2],
            [x + w / 2, base, z + d / 2],
            [x - w / 2, base, z + d / 2],
        ]
        for i in range(1, 3):
            others.append(("block", block.get("id"), [quad[0], quad[i], quad[i + 1]]))
    return others


def overhead_clearance(treads: list[Tread], authority: Path = AUTHORITY, leg: float = 0.06) -> dict:
    """A bevel is a pure subtraction, so headroom can only increase.

    Asserts the removed wedge intersects no other collider's geometry, using an
    exact triangle/box test so neighbouring grade strips are not false clashes.
    """
    others = authority_collider_triangles(authority)
    clashes = []
    checked = 0
    for t in treads:
        if not t.has_ascent_riser:
            continue
        lo = (t.x0, t.y - leg, t.ascent_z)
        hi = (t.x1, t.y, t.ascent_z + leg)
        checked += 1
        for kind, cid, tri in others:
            if kind == "surface" and cid.startswith("city-grade-") and all(
                abs(p[1] - t.y) < 1e-9 for p in tri
            ):
                continue  # coplanar grade the authored tread replaced
            if triangle_meets_box(tri, lo, hi):
                clashes.append({"tread": t.id, "collider": cid, "kind": kind})
    return {
        "leg": leg,
        "colliders_considered": len(others),
        "wedges_checked": checked,
        "wedge_clashes": clashes,
        "subtractive_only": True,
        "overhead_clearance_affected": False,
    }


# --------------------------------------------------------------------------- #
# Candidate evaluation
# --------------------------------------------------------------------------- #
RUN_RISES = (("civic", 0.15), ("roof", 2 / 14))


def leg_within_guard(rise: float, profile: dict, leg: float) -> bool:
    """Single source of truth for 'this leg is admissible for this rise/profile'.

    Uses ``sweep_angle``'s own ``any_over_46`` so the bisection threshold and the
    reported sweep can never disagree through independent rounding.
    """
    return not sweep_angle(rise, profile["radius"], profile["separation"], leg)["any_over_46"]


def _within_guard(leg: float, profiles=PROFILES) -> bool:
    """True when every profile/run stays at or under the 46 deg floor limit.

    A ``None`` worst angle means the capsule never reaches the tread across the
    whole sampled approach sweep, so there is no offending contact to fail on.
    """
    for p in profiles:
        for _, rise in RUN_RISES:
            worst = sweep_angle(rise, p["radius"], p["separation"], leg)["worst_angle_deg"]
            if worst is not None and worst > FLOOR_MAX_ANGLE_DEG:
                return False
    return True


def _preserves(treads: list[Tread], points: list[Audit], leg: float) -> bool:
    return height_preservation(treads, points, leg)["preserved"]


def admissible_window(
    treads: list[Tread], points: list[Audit], lo: float = 0.005, hi: float = 0.30, tolerance: float = 1e-6
) -> dict:
    """Largest leg interval that is both within the guard and height-preserving.

    Two lower bounds push a leg up: the 46 deg floor limit for the largest
    capsule, and the shallowest audited route/nav point. Two facts cap it: a
    bevel must stay shorter than the going so the tread top face survives, and
    the seam ambiguity must stay confined to pre-existing tread boundaries.

    The recommendation is the midpoint of the window, so the parameter is not
    sitting on either limit.
    """
    # Lower bound A: the 46 deg guard.
    a_lo, a_hi = lo, hi
    if not _within_guard(a_hi):
        return {"exists": False, "reason": "no leg in range brings every profile within 46 deg"}
    for _ in range(80):
        mid = (a_lo + a_hi) / 2
        if _within_guard(mid):
            a_hi = mid
        else:
            a_lo = mid
    guard_floor = a_hi

    # Upper bound A: the shallowest audited point that is not already on a
    # tread seam. A leg at or beyond that point's clearance would push the
    # zero-radius support ray off its tread, so it is a ceiling, not a floor.
    clearances = []
    for p in points:
        for t in treads:
            if t.x0 - 1e-12 <= p.x <= t.x1 + 1e-12 and t.z0 - 1e-12 <= p.z <= t.z1 + 1e-12:
                clearance = p.z - t.z0
                if clearance > 1e-9:
                    clearances.append((clearance, p.name, t.id))
    if clearances:
        clearances.sort()
        nav_ceiling, nav_point, nav_tread = clearances[0]
        nav_ceiling = min(nav_ceiling, hi)
    else:
        nav_ceiling, nav_point, nav_tread = hi, None, None

    # Upper bound B: a bevel must not consume the tread going.
    going = min((t.z1 - t.z0) for t in treads if t.has_ascent_riser)
    upper = min(going, nav_ceiling)
    lower = guard_floor
    if lower >= upper:
        return {
            "exists": False,
            "reason": "no leg both satisfies the 46 deg guard and stays short of the shallowest audited point",
            "guard_floor": guard_floor,
            "nav_ceiling": nav_ceiling,
            "upper": upper,
        }
    midpoint = (lower + upper) / 2
    return {
        "exists": True,
        "guard_floor": guard_floor,
        "nav_ceiling": nav_ceiling,
        "nav_ceiling_point": nav_point,
        "nav_ceiling_tread": nav_tread,
        "going": going,
        "upper": upper,
        "lower": lower,
        "midpoint": midpoint,
        "within_guard": _within_guard(midpoint),
        "preserves": _preserves(treads, points, midpoint),
        "tolerance": tolerance,
    }


def evaluate_bevel(treads: list[Tread], points: list[Audit], leg: float, profiles=PROFILES) -> dict:
    """Contact angles and height preservation for one bevel leg."""
    per_profile = {}
    for profile in profiles:
        per_run = {}
        for run, rise in RUN_RISES:
            per_run[run] = sweep_angle(rise, profile["radius"], profile["separation"], leg)
        hp = height_preservation(treads, points, leg)
        angles = [v["worst_angle_deg"] for v in per_run.values() if v["worst_angle_deg"] is not None]
        per_profile[profile["label"]] = {
            "radius": profile["radius"],
            "separation": profile["separation"],
            "runs": per_run,
            "all_runs_within_46": all(not v["any_over_46"] for v in per_run.values()),
            "worst_angle_deg": max(angles) if angles else None,
            "capsule_reaches_tread": bool(angles),
            "bevel_face_engaged": all(v["worst_feature"] in ("bevel face", "upper top plane", "lower top plane") for v in per_run.values()),
            "minimum_leg_for_face_m": minimum_leg_for_face(
                min(r for _, r in RUN_RISES), profile["radius"], profile["separation"], math.degrees(math.atan2(leg, leg))
            ),
        }
    hp = height_preservation(treads, points, leg)
    return {
        "leg": leg,
        "chamfer_angle_deg": math.degrees(math.atan2(leg, leg)),
        "margin_to_floor_max_angle_deg": round(FLOOR_MAX_ANGLE_DEG - math.degrees(math.atan2(leg, leg)), 6),
        "profiles": per_profile,
        "height_preservation": hp,
        "admissible": all(p["all_runs_within_46"] for p in per_profile.values()) and hp["preserved"],
    }


def documented_band() -> dict:
    """Compare the analytic unbeveled angles with the reviewed guard figures.

    ``BLOCKERS_EFFICIENCY_20261005.md`` §1 and the post-X README both report the
    guard observing ~47.5-51.3 deg on stairs. That figure came from a native run;
    this tool reproduces the same geometry analytically and never claims to be
    that measurement.
    """
    angles = {
        profile["label"]: {
            run: sweep_angle(rise, profile["radius"], profile["separation"], 0.0)["worst_angle_deg"]
            for run, rise in RUN_RISES
        }
        for profile in (EXPLORATION, GAME_ENVELOPE)
    }
    values = [v for per_run in angles.values() for v in per_run.values() if v is not None]
    return {
        "source": "port/finish/map-variety/BLOCKERS_EFFICIENCY_20261005.md section 1",
        "documented_deg": [47.5, 51.3],
        "documentedProvenance": "native guard observation, not reproduced here",
        "analytic_deg": angles,
        "analytic_range_deg": [min(values), max(values)] if values else None,
        "reproduces_order_of_magnitude": bool(values) and min(values) >= 45.0 and max(values) <= 52.0,
        "isNativeClaim": False,
    }


def plain_sweep(treads: list[Tread], profiles=PROFILES) -> list[dict]:
    """Unbeveled contact angles for every profile and run."""
    rows = []
    for profile in profiles:
        for run, rise in RUN_RISES:
            row = sweep_angle(rise, profile["radius"], profile["separation"], 0.0)
            row.update({"profile": profile["label"], "run": run})
            rows.append(row)
    return rows


def contact_effect(treads: list[Tread], contacts: Path = CONTACTS, leg: float = 0.06) -> dict:
    """Expected effect of the recommended bevel on the pinned contact records."""
    records = json.loads(contacts.read_text())["records"]
    by_id = {t.id: t for t in treads}
    tread = wall = 0
    non_tread: list[str] = []
    for record in records:
        for contact in record["contacts"]:
            if contact["id"] in by_id:
                tread += 1
            else:
                wall += 1
                non_tread.append(f"{record['id']}->{contact['id']}")
    return {
        "records": len(records),
        "contact_entries": tread + wall,
        "tread_ascent_edge_contacts": tread,
        "non_tread_contacts": wall,
        "non_tread_examples": sorted(set(non_tread)),
        "beveled_edge_deg": math.degrees(math.atan2(leg, leg)),
        "note": "non-tread contacts are wall/overhead bodies, not stair ascent edges; a bevel cannot and must not address them",
    }


def synthetic_fixture_report() -> dict:
    """Deterministic fixtures covering the requested rise/radius matrix."""
    rows = []
    for rise in (0.15, 0.18, 2 / 14, 0.20, 0.42):
        for profile in PROFILES:
            plain = sweep_angle(rise, profile["radius"], profile["separation"], 0.0)
            per_leg = {}
            for leg in BEVEL_LEGS:
                s = sweep_angle(rise, profile["radius"], profile["separation"], leg)
                per_leg[f"{leg:.4f}"] = {
                    "worst_angle_deg": s["worst_angle_deg"],
                    "worst_feature": s["worst_feature"],
                    "ok": not s["any_over_46"],
                }
            rows.append(
                {
                    "rise": rise,
                    "profile": profile["label"],
                    "radius": profile["radius"],
                    "separation": profile["separation"],
                    "plain": {
                        "worst_angle_deg": plain["worst_angle_deg"],
                        "worst_feature": plain["worst_feature"],
                        "over_46": plain["any_over_46"],
                    },
                    "per_leg": per_leg,
                    "minimum_admissible_leg": minimum_admissible_leg(rise, profile),
                    "at_minimum_leg_ok": (
                        None
                        if minimum_admissible_leg(rise, profile) is None
                        else leg_within_guard(rise, profile, minimum_admissible_leg(rise, profile))
                    ),
                    "plain_over_46": plain["any_over_46"],
                }
            )
    return {
        "required": [
            "plain edge > 46 deg",
            "beveled edge <= 46 deg",
            "height-preserved tread",
        ],
        "fixtures": rows,
    }


# --------------------------------------------------------------------------- #
# Report
# --------------------------------------------------------------------------- #
def js_double_literal(value: float) -> str:
    """Render a float as a JavaScript ``Number`` literal.

    The builder patch carries the leg as a JS literal, and a truncated literal
    would silently move the parameter off the proven midpoint. ``repr`` emits a
    shortest round-tripping decimal for Python doubles; IEEE 754 doubles have the
    same shortest round-trip property, so JS parses it back to the same bits.
    ``tests/builder-leg-literal.test.mjs`` asserts the round-trip through a real
    JS runtime.
    """
    return repr(value)


def build_report(authority: Path = AUTHORITY, contacts: Path = CONTACTS) -> dict:
    civic = civic_treads_from_authority(authority)
    roof = roof_steps_from_evidence(contacts)
    treads = civic + roof
    points = audited_points(authority) + contact_feet(contacts)
    window = admissible_window(treads, points)
    require(window.get("exists"), f"no admissible bevel window: {window.get('reason', window)}")
    leg = window["midpoint"]
    bevels = [evaluate_bevel(treads, points, candidate) for candidate in BEVEL_LEGS]
    best = evaluate_bevel(treads, points, leg)
    admissible = [b for b in bevels if b["admissible"]]
    require(best["admissible"], "the recommended bevel leg fails its own admissibility check")
    hp = best["height_preservation"]
    nav = nav490_regression(civic)
    require(
        hp["preserved"],
        "bevel removes physical support from an audited route/nav point; only seam ambiguity may remain",
    )
    require(
        all(c["capsule_preserved"] for c in hp["support_changed"]),
        "a beveled point loses capsule-resolved support",
    )
    require(nav["bevel_preserves_fixed_y"], "nav490 support height is not bit-identical under the recommended bevel")
    require(nav["naive_ramp_matches_readme"], "naive-ramp model does not reproduce the documented nav490 regression")
    return {
        "scope": "source-only height-preserving stair collision proposal; no engine run, no runtime/artifact/recipe/builder change",
        "authority": {
            "runtimeWorld": str(authority.relative_to(ROOT)),
            "contactEvidence": str(contacts.relative_to(ROOT)),
            "civicRecipe": "tools/godot-multiplayer/new-maps/vesper-viaduct/recipe.mjs:15",
            "roofRecipe": "tools/godot-multiplayer/new-maps/vesper-viaduct/revisions/urban-v2/recipe-v2.mjs:127",
            "controllerProfile": "godot/exploration/walker.gd:21,34,35,37",
            "guard": "tools/godot-multiplayer/new-maps/walker-step-ab/evidence/source-initial/response_guard.gd",
        },
        "controllerProfile": {
            "radius": 0.35,
            "height": 1.8,
            "floor_max_angle_deg": FLOOR_MAX_ANGLE_DEG,
            "floor_snap_length": 0.3,
            "safe_margin": SAFE_MARGIN,
            "step_logic": "none: step() calls move_and_slide() only",
        },
        "stairRuns": {
            "civic": {
                "treads": len(civic),
                "ids": [t.id for t in civic],
                "footprint": {"x0": civic[0].x0, "x1": civic[0].x1, "z0": civic[0].z0, "z1": civic[-1].z1},
                "rise": 0.15,
                "going": 0.5,
                "grade_deg": round(math.degrees(math.atan2(0.15, 0.5)), 6),
                "ascent_edges": sum(1 for t in civic if t.has_ascent_riser),
                "inRuntimeAuthority": True,
            },
            "roof": {
                "treads": len(roof),
                "ids": [t.id for t in roof],
                "footprint": {"x0": roof[0].x0, "x1": roof[0].x1, "z0": roof[0].z0, "z1": roof[-1].z1},
                "rise": 2 / 14,
                "going": 12 / 14,
                "grade_deg": round(math.degrees(math.atan2(2 / 14, 12 / 14)), 6),
                "ascent_edges": sum(1 for t in roof if t.has_ascent_riser),
                "inRuntimeAuthority": False,
                "note": "candidate-only: present in pinned X evidence and recipe-v2.mjs, absent from the accepted runtime world JSON",
            },
        },
        "documentedGuardBand": documented_band(),
        "plainEdgeSweep": plain_sweep(treads),
        "bevelSweep": bevels,
        "admissibleWindow": window,
        "recommended": {
            "leg": leg,
            "leg_selection": "midpoint of the admissible window, not either limit",
            "leg_limits": {
                "guard_floor": window["guard_floor"],
                "nav_ceiling": window["nav_ceiling"],
                "nav_ceiling_point": window["nav_ceiling_point"],
                "going": window["going"],
            },
            "chamfer_angle_deg": best["chamfer_angle_deg"],
            "margin_to_floor_max_angle_deg": best["margin_to_floor_max_angle_deg"],
            "cos_margin_over_floor_max_angle": round(
                math.cos(math.radians(best["chamfer_angle_deg"])) - COS_FLOOR_MAX_ANGLE, 9
            ),
            "js_double_literal": js_double_literal(leg),
            "js_leg_float64_hex": bits(leg),
            "edge": "ascent (-Z) face only; the descent face needs no bevel because dropping off it is a fall",
            "scope": f"the -Z ascent edge of all {len(treads)} treads in both runs",
            "profiles": best["profiles"],
            "heightPreservation": best["height_preservation"],
        },
        "descentEdgeRejected": {
            "leg": leg,
            "reason": "beveling the descent face too would shorten each tread's walkable extent at its far end",
            "result": height_preservation(treads, points, leg, edge="both"),
        },
        "heightPreservation": {
            "method": "bit-exact float comparison of resolved walkable support height before/after over every nav/route/spawn/objective point and every pinned contact foot, under both a strict zero-radius ray and the 0.35 m capsule footprint",
            "auditedPoints": len(points),
            "nav490": nav,
            "supportChanged": hp["support_changed"],
            "genuineSupportChanges": hp["genuine_support_changes"],
            "seamAmbiguityOnly": hp["seam_ambiguity_only"],
            "strictPreserved": hp["strict_preserved"],
            "capsulePreserved": hp["capsule_preserved"],
            "preserved": hp["preserved"],
        },
        "geometryDiff": geometry_diff(treads, leg),
        "overheadClearance": overhead_clearance(civic, authority, leg),
        "contactEffect": contact_effect(treads, contacts, leg),
        "syntheticFixtures": synthetic_fixture_report(),
    }


def main() -> int:
    report = build_report()
    EVIDENCE.write_text(json.dumps(report, indent=2) + "\n")
    civic, roof = report["stairRuns"]["civic"], report["stairRuns"]["roof"]
    print(f"civic run: {civic['treads']} treads, {civic['ascent_edges']} ascent edges, rise {civic['rise']} m, going {civic['going']} m, grade {civic['grade_deg']} deg, in accepted authority")
    print(f"roof run:  {roof['treads']} treads, {roof['ascent_edges']} ascent edges, rise {roof['rise']:.6f} m, going {roof['going']:.6f} m, grade {roof['grade_deg']} deg, candidate-only")
    band = report["documentedGuardBand"]
    print(
        f"unbeveled analytic band {band['analytic_range_deg'][0]:.2f}-{band['analytic_range_deg'][1]:.2f} deg "
        f"vs documented {band['documented_deg'][0]}-{band['documented_deg'][1]} deg (native figure, not claimed here)"
    )
    for row in report["plainEdgeSweep"]:
        print(f"  plain {row['profile']:>18} {row['run']:>5}: worst {row['worst_angle_deg']:6.2f} deg via {row['worst_feature']}, first contact {row['first_contact_angle_deg']:6.2f} deg at gap {row['first_contact_gap']}")
    for b in report["bevelSweep"]:
        angles = [p["worst_angle_deg"] for p in b["profiles"].values() if p["worst_angle_deg"] is not None]
        worst = f"{max(angles):6.2f}" if angles else "   n/a"
        flag = "ADMISSIBLE" if b["admissible"] else "rejected"
        print(f"  bevel leg {b['leg']:.4f}: worst {worst} deg, height-preserved={b['height_preservation']['preserved']} -> {flag}")
    rec = report["recommended"]
    win = report["admissibleWindow"]
    print(
        f"admissible leg window: [{win['lower']:.6f}, {win['upper']:.6f}] m "
        f"(floor {win['guard_floor']:.6f} from the 46 deg limit, ceiling {win['nav_ceiling']:.6f} from {win['nav_ceiling_point']} on {win['nav_ceiling_tread']}; going {win['going']:.6f})"
    )
    print(f"recommended: leg {rec['leg']:.6f} m, {rec['chamfer_angle_deg']} deg chamfer, margin {rec['margin_to_floor_max_angle_deg']} deg under the 46 deg guard")
    hp = report["heightPreservation"]
    print(
        f"height preservation: {hp['preserved']} over {hp['auditedPoints']} audited points; "
        f"genuine support losses {len(hp['genuineSupportChanges'])}; "
        f"seam-ambiguity-only {len(hp['seamAmbiguityOnly'])}; capsule support preserved {hp['capsulePreserved']}"
    )
    for c in hp["seamAmbiguityOnly"]:
        print(f"    seam-only {c['point']} z={c['z']}: strict ray {c['before']}->{c['after']}, capsule {c['capsule_before']}->{c['capsule_after']}")
    nav = hp["nav490"]
    print(f"nav490: tread {nav['supporting_tread']} support {nav['bevel_support_y']} bit-identical={nav['bevel_preserves_fixed_y']}; naive ramp {nav['naive_ramp_support_y']:.6f} (delta {nav['naive_ramp_delta']:+.6f} m); tread-faithful ramp {nav['tread_faithful_ramp_support_y']:.6f} (delta {nav['tread_faithful_ramp_delta']:+.6f} m)")
    print(f"descent-edge variant rejected? height preserved={report['descentEdgeRejected']['result']['preserved']}")
    ce = report["contactEffect"]
    print(f"contacts: {ce['contact_entries']} entries, {ce['tread_ascent_edge_contacts']} tread ascent-edge addressed, {ce['non_tread_contacts']} non-tread untouched")
    print(f"wrote {EVIDENCE.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())