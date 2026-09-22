#!/bin/bash
# Rehearsal 1: wait for a frozen primary checkout, then run the full pipeline dry run.
# Default verification mode: preflight is real, verification/package/publish/verify/push
# are printed and skipped, which is exactly what "dry run by default" promises.
set -u
REPO=/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port
EVID=$REPO/port/native-release-pipeline/evidence
TAG=release-pipeline-dryrun-primary-2026-09-22
mkdir -p "$EVID"

clean() {
  # Frozen = no modified/staged tracked file, and no untracked runtime file.
  # Evidence/report/handoff paths are exempt exactly as the pipeline treats them.
  git -C "$REPO" status --porcelain=v1 -uall \
    | grep -vE '^.{2} (port/handoffs/|port/[^/]+/[^/]*evidence/|reports/)' \
    | grep -q . && return 1
  return 0
}

streak=0
for _ in $(seq 1 180); do
  if clean; then streak=$((streak + 1)); else streak=0; fi
  [ "$streak" -ge 2 ] && break
  sleep 30
done
if [ "$streak" -lt 2 ]; then
  echo "no frozen window within the wait budget" > "$EVID/dry-run-primary-status.txt"
  exit 3
fi

cd "$REPO"
git rev-parse HEAD > "$EVID/dry-run-primary-head.txt"
git status --porcelain=v1 -uall > "$EVID/dry-run-primary-status-before.txt"
date -u +%Y-%m-%dT%H:%M:%SZ > "$EVID/dry-run-primary-started-at.txt"
node tools/release/release.mjs --tag="$TAG" > "$EVID/dry-run-primary-console.log" 2>&1
echo "$?" > "$EVID/dry-run-primary-exit-code.txt"
cp -r "/tmp/opencode/cocs-release-$TAG/runs/." "$EVID/dry-run-primary-state-runs/"
git status --porcelain=v1 -uall > "$EVID/dry-run-primary-status-after.txt"
date -u +%Y-%m-%dT%H:%M:%SZ > "$EVID/dry-run-primary-finished-at.txt"
echo done > "$EVID/dry-run-primary-status.txt"
