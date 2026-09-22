# Combined native match selection

The lead ran `port/native-match-selection/run.mjs` from private integration at
`48ab052`, with the integrated scoreboard, audio and combat overlay:

```sh
node tools/godot-export/semantic.mjs
GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 \
GUEST_NODE_MODULES=/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/node_modules \
node port/native-match-selection/run.mjs --output=/tmp/opencode/match-selection-independent
```

Exit 0. All six Meridian/Verdant/Ember × Deathmatch/Instagib combinations produced
authoritative matching map/mode snapshots and passed native movement/fire/ACK
smoke. The graphical setup test selected Verdant/Instagib and joined the actual
owned normal-rate authority. Logs and `results.json` are copied here unchanged.

The subsequent `menu-960.png` is a setup-only visual render with the corrected
top-left panel anchoring; no connection or gameplay is claimed for that image.
Its owned render process group cleanup is recorded in `render-960.json`.
