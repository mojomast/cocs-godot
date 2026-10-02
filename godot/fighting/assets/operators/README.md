# Operator animation exports

**Source-ready; no fighting GLBs have been generated or accepted yet.**

The runtime expects `<operator>.glb` and `<operator>.json` here. The JSON records
the source GLB, Blender master, recipe pipeline and content hashes, explicit seek
knots, mapped bones, sockets and acceptance status. Masters live outside Godot at
`tools/fighting/animation/masters/`.

All nine source skeleton rests match. The Meta master owns 25 shared victim
Actions; other masters link those Actions rather than authoring 225 variants.
Initial GLBs remain self-contained for the Meta/Mistral native proof. Shared
runtime AnimationLibrary storage is a later measured optimization; it is not
claimed implemented. See `port/fighting/animation/README.md` for the closure and
serial heavy-slot commands.
