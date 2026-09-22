# Incorrect harness invocation preserved

The lead invoked `godot/tests/showcase/physics.gd` with `--headless` and a
180-second subprocess limit. It timed out. That script exercises parsed window
input and its delivered reproduction command uses a private Xvfb, Compatibility,
`--disable-render-loop --fixed-fps 60`; headless was not its accepted harness.
The interrupted subprocess's partial output was not saved by this first helper.

The aggregate now runs native-only headless startup, while the 49-check graphical
physics fixture and independent actual-X11 controller review retain their own
explicit acceptance scope. This is not claimed as a gameplay regression or a
successful headless traversal. The timed-out subprocess was killed/reaped by
Python's subprocess.run context.
