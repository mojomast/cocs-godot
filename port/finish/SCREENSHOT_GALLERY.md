# Twelve-hour screenshot gallery

Owner-requested snapshot: **2026-10-02 00:29:33–12:29:33 EDT (UTC−04:00)**.

- Tailscale URL: <http://100.125.104.79:8796/>
- Optional MagicDNS URL: <http://kimi.tailec998.ts.net:8796/>
- Snapshot root: `/home/mojo/.tmp-on-disk/cocs-screenshot-gallery-20261002-1229/`
- 643 named screenshots and 9,005 capture frames: 9,648 unique images from
  9,996 source files. Duplicate images retain all matching source paths.
- Default view shows named screenshots; the type filter exposes every capture
  frame. Search, workstream filters, pagination, full-resolution viewer/downloads
  and source timestamps are included.
- Uses saved-file modification time, which can differ from original capture time.
  Excludes 74,100 known historical checkout copies and unrelated project images.
  Failed/rejected capture attempts remain visible and labeled by original paths.
- Originals were copied into the gallery snapshot; a SHA-256 manifest records
  image content. No Blender/Godot or video encoding work was run for the gallery.

Served with Python's HTTP server bound only to the Tailscale IPv4 address, port
8796. Port 8787 was occupied and was left untouched. Server shell ID:
`sh_0fd76e973001uKkGPmtYLQc7go`.

Verified HTTP index/manifest, JavaScript syntax and three image downloads against
their hashes. Desktop browser was disconnected; rendered browser inspection was
unavailable. Generator and page: `tools/release/screenshot-gallery/`.
