# Evidence validity and capture correction

Only render-1790081900090569141 has verified native PNG dimensions across all three requested resolutions. Its runner.json records parsed PNG widths/heights independently of Godot, and the Godot capture script now fails if the actual Image dimensions differ from the request.

Earlier capture-second/, render-1790081033796500595/ and render-1790081488686854200/ were rendered at 1280x800 regardless of the requested filename/report resolution. Godot startup reapplied project.godot's viewport size after SceneTree._initialize. They remain historical failure evidence; their 960x640/1920x1080 resolution labels and any corresponding resolution-specific performance interpretation are INVALID. They are not genuine resized copies either: the renderer remained 1280x800. The valid1280x800 historical images remain real pixels, but visual review is still pending.

The fix applies window sizing from the deferred run method after engine startup, disables content scaling and checks actual output image dimensions. Current 45 PNGs are verified 960x640,1280x800,1920x1080 respectively; per-resolution timing reports now correspond to the actual requested render size. Browser service HTTP500 prevented visual inspection, so file/dimension validation is not called visual acceptance.

render-1790081061279699658/ requested1280x800 graybox and actually rendered1280x800. It is a valid historical graybox fixture, before final ramp-infill correction.

normal-rate-1790080351144/ is GRAYBOX source-mode evidence and predates art geometry. normal-rate-1790081080415/ adds the first art but predates ramp-infill collision correction. normal-rate-1790081542205/ uses current canonical geometry hashes and contains the compressed exact recipes. All are in-process source tests, NOT a native-client or WebSocket acceptance run.

Failed graybox*.json and rays-first.json are deliberately preserved. See ../HANDOFF.md for failure-to-fix explanations. Reports with passed:false must never be counted as passing because the files exist.
