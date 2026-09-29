# FAILED/HISTORICAL capture — do not use as corrected color evidence

These images and `metrics.json` were produced by commit `8c3acba6`. It assigned
`Color(hex).srgb_to_linear()` to Godot `StandardMaterial3D` albedo and emission,
even though the material's `source_color` shader uniforms perform that conversion.
All six rendered finishes were consequently double-converted and too dark. The
images are retained to document the failed attempt; corrected captures belong
in the parent `evidence/` directory after rerunning `finishes_capture.gd`.
