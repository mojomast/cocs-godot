# Additional Astra improvement, porting and Blender workstreams

The owner explicitly requested another fan-out for more improvements, source
features and Blender assets/maps. **Six additional `openai/gpt-6-astra` agents**
start from `27cfaa14` in isolated branches. Their common contract is [BRIEF.md](BRIEF.md).
This expands ongoing work; it does not replace the second feature pass or the
three original new maps.

## Active lanes

| Lane | Agent | Branch | Deliverable |
|---|---|---|---|
| Vesper Viaduct | `ses_f03a3885fffehx9yFhHubuPCft` | `expansion-three/vesper` | Dense urban rail/canal map: stepped city blocks, station concourse, brick arcades, warehouse passages and courtyards |
| Abyssal Pressureworks | `ses_f03a3024cffeNO1Cc3Qr1zSLTG` | `expansion-three/abyssal` | Deep-ocean dry habitat: faceted pressure halls, observation labs, central equalizer, terraced operations rooms and maintenance routes |
| Robot asset ensemble | `ses_f03a2843bffefDFoP3x1j1cxRO` | `expansion-three/robots` | Three distinct Blender robot bodies for existing roles, compatible rigs/animation and a small supporting machinery-prop kit |
| Blackwater Horde | `ses_f03a202c5ffeXk5HRJ1OcEfL5t` | `expansion-three/horde` | Mission/upgrade guidance and input-flow improvements, with ordinary-input machinery/Warden completion work |
| LATTICE | `ses_f03a180eaffe5qX6gxggbXBBmr` | `expansion-three/lattice` | Audit and implement missing contextual command/entity information and dynamic event feedback without exposing private state |
| Audio | `ses_f03a0d083ffeCTGibA7fDkb3dr` | `expansion-three/audio` | Actual-source audio parity gaps, combat readability, bounded voices and lifecycle/recorded-audio verification |

Worktrees: `/home/mojo/.tmp-on-disk/cocs-expansion-three-<lane>-20261002`.
Evidence: `/home/mojo/.tmp-on-disk/cocs-expansion-three-<lane>-evidence-20261002`.
No nested agents. New map IDs are `vesper-viaduct` and `abyssal-pressureworks`.
Their candidate modes are design targets until source/native journeys pass.

## Source/code checkpoints

- **Vesper — `9b1d8b86`, ready for Blender.** A 280×240 m urban recipe with
  24 m relief, nineteen routes, seven connected three-room interiors, station
  halls, brick arcades, stepped blocks and canal warehouses. All routes passed
  both-way source movement (29,276 ticks); all 2,143 generated navigation nodes
  connect. Source body/ray contacts, real door/window apertures, ceilings,
  walkable-footprint separation and canal/bridge support checks passed.
- Six controlled source rounds passed: DM/TDM ended on time after legitimate
  input-fired kills; CTF completed three physically carried captures; Domination,
  KOTH and Uplink ended through objectives. These are source fixtures, not native
  or autonomous-bot acceptance. Geometry hash:
  `1e9ad354a2d4f474f783289043380cd7ea046ca5631cd829715c627d0bc37548`.
- Blender scripts and native collision probe are prepared but unexecuted. Actual
  architecture review, stair/body agreement, hosted native modes, HUD/capture
  budgets and package acceptance remain pending. Parent must resolve the named
  `res://multiplayer_worlds/art/vesper-viaduct/vesper-viaduct.glb` binding before
  production acceptance. No shared registration or engine grant is implied.

- **Abyssal — `67f79981`, ready for Blender.** Twelve pressure chambers in three
  districts, seventeen angled gallery routes, eight crosslinks and 20 m walkable
  relief are authored as a deterministic source/native geometry recipe. Blender
  export scripts are prepared; no master or GLB has been produced.
- **12/12 Node checks passed:** all seventeen routes walked both directions,
  935 connected nav nodes / 2,943 undirected edges, sustained body contact against
  58 shell segments, 34 portal and twelve ceiling ray checks, reciprocal overlook
  counterfire, physical source CTF capture and KOTH/Domination/Holdout scoring
  wins. Autonomous checks observe only fifteen simulated seconds per candidate
  mode with supported movement; they do not prove bot round completion.
- Native architectural/collision inspection, hosted inputs, wide/compact HUD,
  measured rendering/capture budgets and final registration remain pending.
  Core identity, generator freshness and Python syntax checks passed. This
  checkpoint does not grant an engine slot or approve a published mode pair.

- **Robots — `fb9715fb`, ready for Blender.** Three authored skin recipes:
  Needle Surveyor (skirmisher), Caisson Guard (bulwark), and Kiln Tender (mortar),
  each with three compatible LOD assemblies. Six workshop prop recipes and
  Blender master/reference-animation/rigid-runtime export scripts are prepared.
  The additive adapter validates complete assemblies and retains original meshes.
- **25 source/regression tests passed**, including six new recipe contracts,
  fifteen existing targeting/role tests and four Horde authority tests. Existing
  targeting triangle samples are baseline regression evidence, not measurements
  of the unbuilt skins. Three Python files passed syntax checks.
- No robot GLB, master, render or native import exists yet. Runtime motion reuses
  the existing robot pipeline; per-skin idle reference clips are not connected.
  Factory selection, actual animated contact/targeting comparison, silhouette and
  foot-plant review, gameplay captures and measured budgets remain pending.
  The source handoff does not grant a heavy slot or install skins in the game.

## Queue and acceptance

**Parallax retains the exclusive Blender/Godot slot.** The new agents may perform
design, source research, authoring scripts, implementation and Node checks now.
No new lane has an engine grant. Existing Helix/Foundry architectural revisions
and four second-pass feature lanes retain their places ahead of these additions.
All heavy execution requires an explicit parent grant after the current owner
has stopped its processes and released the slot.

The map briefs require substantial built districts and distinctive interiors from
the first recipe, plus real movement/cover/objective geometry. Asset work must
preserve the source roles, hit regions and attachment/animation contracts. Source
feature lanes must prove genuine gaps before implementation and prepare runnable
connected acceptance rather than only test plans.

Parent integrates shared hooks/catalogs, validates runtime dependency closure,
runs merged checks and publishes verified builds and screenshots. The current
published release remains `e731fd53`; nothing in this launch record claims new
assets, native acceptance or inclusion in a release.
