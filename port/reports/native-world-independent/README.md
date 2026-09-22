# Independent native world and Puma image review

At integrated runtime `e2fd1d3`, with the capture helper's new `--all` option:

```sh
GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 \
python3 port/native-world-presentation/capture.py /tmp/opencode/all-native-worlds --all

TMPDIR=/tmp/opencode \
GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 \
python3 port/tools/native_vehicle_demo/run.py --capture=/tmp/opencode/puma-independent.png
```

Both commands exited 0. Each used a private owned Xvfb, Compatibility renderer,
Mesa llvmpipe and bounded child processes. The native world logs are copied
unchanged and hashed in `inventory.json`. Unsupported VSync is the only driver
warning in these captures. Puma independently passed `checks=19 failures=0`;
its screenshot returned save=0 and was copied as `puma-synthetic.png`.

The lead opened and inspected every image individually:

- Meridian: pale civic buildings, open doorways, visible landmarks and skyline.
- Verdant: green environment, courtyard buildings and arches.
- Ember: warm dark surfaces, illuminated accents and distinct towers/routes.
- Tidal: cold light surfaces and separated dark floor panels; high brightness
  still merits human review, but geometry is visible rather than blank.
- Sunscar: sand/copper palette and long divided routes.
- Asterion: orbital-blue palette, distributed relay buildings and skyline.
- Monsoon: green-gray industrial layout and vegetation accents.
- Ion: track boundary shape and dashed centerline are visible.
- Aurora: enclosed pitch, stands, center circle and halfway markings visible.
- Puma: front/rear silhouettes, wheels, cage and team accents visible.

These are **offline native viewer overview cameras** and a **synthetic Puma
fixture**. They do not establish route traversal, dynamic objectives, human
readability during combat, hardware performance or live driving. Several large
maps extend beyond the common overview frame. Broader gameplay review remains
open. Source solid/triangle compatibility was independently checked earlier at
`edc222f`; camera framing is not a geometry-completeness assertion.
