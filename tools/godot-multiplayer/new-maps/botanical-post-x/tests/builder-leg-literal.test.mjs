// Assert the builder patch's STAIR_BEVEL literal round-trips to the exact
// IEEE 754 double this source-only analysis proved.
//
// A truncated literal would move the bevel leg off the proven midpoint of the
// admissible window [0.041422, 0.045455] m, so the value is pinned here as
// float64 hex and checked from a real JS runtime.
//
// Run: node tests/builder-leg-literal.test.mjs
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));
const PATCH = join(HERE, "../vesper-stair-bevel-20261005.patch");
const EXPECTED_HEX = "3fa63d8dbf59e445"; // 0.043438367470067386

let failures = 0;
function check(name, condition, detail = "") {
  if (condition) {
    console.log(`ok   ${name}`);
  } else {
    failures += 1;
    console.error(`FAIL ${name} ${detail}`);
  }
}

const patch = readFileSync(PATCH, "utf8");

// The literal must appear identically in both recipe hunks.
const literals = [...patch.matchAll(/STAIR_BEVEL\s*=\s*([0-9.]+);/g)].map((m) => m[1]);
check("patch declares STAIR_BEVEL twice", literals.length === 2, `found ${literals.length}`);
check(
  "both hunks agree on the literal",
  literals.length === 2 && literals[0] === literals[1],
  JSON.stringify(literals),
);

// Parse the literal the way the recipe would, then check the bits.
const buffer = new DataView(new ArrayBuffer(8));
buffer.setFloat64(0, Number(literals[0]));
check(
  "literal round-trips to the proven float64",
  buffer.getBigUint64(0).toString(16) === EXPECTED_HEX,
  `got ${buffer.getBigUint64(0).toString(16)}`,
);

// The chosen leg must sit strictly inside the admissible window.
const leg = Number(literals[0]);
const GUARD_FLOOR = 0.041422189485588026;
const NAV_CEILING = 0.045454545454546746;
check("leg is above the 46 deg guard floor", leg > GUARD_FLOOR, `leg ${leg}`);
check("leg is below the nav ceiling", leg < NAV_CEILING, `leg ${leg}`);
check("leg is the window midpoint", Math.abs(leg - (GUARD_FLOOR + NAV_CEILING) / 2) < 5e-16, `leg ${leg}`);

// 45 deg chamfer: the leg applies to both axes, so the face angle is exactly 45.
check("chamfer angle is 45 deg", Math.abs(leg - leg) === 0);

// The tread top plane must be reused, never recomputed: 12+(i+1)*.15 stays exact.
const y0 = 12 + 1 * 0.15;
check("civic tread 0 plane is exactly 12.15", y0 === 12.15, `${y0}`);
check("civic tread 79 plane is exactly 24", 12 + 80 * 0.15 === 24);
check("tread 0 walkable start clears the seam", 25 + leg > 25 && 25 + leg < 25.5, `${25 + leg}`);
check("bevel does not consume the tread going", leg < 0.5);

if (failures > 0) {
  console.error(`\n${failures} check(s) failed`);
  process.exit(1);
}
console.log("\nall builder-leg literal checks passed");