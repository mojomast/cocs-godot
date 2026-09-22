#!/bin/bash
# Rehearsal 2: real verification and a real package build from the frozen commit in the
# clean worktree, stopped after package, then a dry-run resume from publish.
#
# The first attempt (kept in refusal-tag-behind-head-*) was refused at preflight because
# the frozen commit is not on the publication remote yet; the rehearsal resumes from
# preflight with --allow-tag-behind-head, which is the documented explicit choice for
# tagging the published branch head. Nothing is published either way: package is the
# last step that runs.
set -u
WT=/tmp/opencode/cocs-release-rehearsal
EVID=/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/port/native-release-pipeline/evidence
TAG=release-pipeline-build-rehearsal-2026-09-22-c
mkdir -p "$EVID"
cd "$WT"
date -u +%Y-%m-%dT%H:%M:%SZ > "$EVID/package-rehearsal-started-at.txt"
node tools/release/release.mjs --tag="$TAG" --execute --verification=always --stop-after=package \
  --allow-tag-behind-head > "$EVID/package-rehearsal-console.log" 2>&1
echo "$?" > "$EVID/package-rehearsal-exit-code.txt"
node tools/release/release.mjs --tag="$TAG" --resume-from=publish >> "$EVID/package-rehearsal-console.log" 2>&1
echo "$?" > "$EVID/package-rehearsal-resume-exit-code.txt"
cp -r "/tmp/opencode/cocs-release-$TAG/runs/." "$EVID/package-rehearsal-state-runs/"
date -u +%Y-%m-%dT%H:%M:%SZ > "$EVID/package-rehearsal-finished-at.txt"
echo done > "$EVID/package-rehearsal-status.txt"
