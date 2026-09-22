#!/bin/bash
# Rehearsal 1: wait for a frozen tree, then run the pipeline end to end in dry run.
# This is the exact command recorded in port/native-release-pipeline/README.md.
set -u
REPO=/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port
EVID=$REPO/port/native-release-pipeline/evidence
TAG=release-pipeline-rehearsal-2026-09-22
mkdir -p "$EVID"

clean() {
  # Frozen = no modified/staged tracked file, and no untracked runtime file.
  git -C "$REPO" status --porcelain=v1 -uall | grep -vE '^\?\? (port/handoffs/procedural-model-generation-llm-research\.md|port/[^/]+/[^/]*evidence/|reports/)' | grep -q . && return 1
  return 0
}

streak=0
for _ in $(seq 1 120); do
  if clean; then
    streak=$((streak + 1))
  else
    streak=0
  fi
  if [ "$streak" -ge 3 ]; then
    break
  fi
  sleep 30
done
if [ "$streak" -lt 3 ]; then
  echo "no frozen window within the wait budget" > "$EVID/dry-run-status.txt"
  exit 3
fi

git -C "$REPO" rev-parse HEAD > "$EVID/dry-run-head-before.txt"
git -C "$REPO" status --porcelain=v1 -uall > "$EVID/dry-run-status-before.txt"
date -u +%Y-%m-%dT%H:%M:%SZ > "$EVID/dry-run-started-at.txt"
node "$REPO/tools/release/release.mjs" --tag="$TAG" --verification=always --poll-seconds=5 \
  > "$EVID/dry-run-console.log" 2>&1
echo "$?" > "$EVID/dry-run-exit-code.txt"
date -u +%Y-%m-%dT%H:%M:%SZ > "$EVID/dry-run-finished-at.txt"
git -C "$REPO" rev-parse HEAD > "$EVID/dry-run-head-after.txt"
git -C "$REPO" status --porcelain=v1 -uall > "$EVID/dry-run-status-after.txt"
cp -r "/tmp/opencode/cocs-release-$TAG/runs" "$EVID/state-runs" 2>/dev/null
echo "done" > "$EVID/dry-run-status.txt"
