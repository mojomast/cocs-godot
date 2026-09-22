# Combat setup availability correction

The independent usability audit at `29b0a59` found working standalone experiences
labelled “Native gameplay pending.” Combat setup now labels them **separate demo**
and displays their exact `--experience`, `--map` and `--mode` relaunch arguments.
The button stays disabled because this screen launches only its own combat modes.
Campaign is explicitly deferred for planning/research. Unsupported modes retain
pending status; routing availability is not full gameplay acceptance.

The lead ran the existing 95-check match-selection suite and the complete
70-gate verifier. Two synthetic real-widget renders were directly inspected at
960×640 and 1280×800: the Ion route fits inside the centered menu at both sizes.
`captures.json` and logs record exact commands; `render-fixture.gd.txt` preserves
the temporary inspection script. These are menu layout fixtures, not new live
gameplay or exported-package screenshots. Final package rebuild follows runtime
integration. Owned Xvfb clients exited and temporary XDG directories were removed.
