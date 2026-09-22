#!/bin/bash
# Rehearsal 1: catch a frozen window on the primary checkout and run the full pipeline
# dry run there. Default verification mode: preflight is real, verification/package/
# publish/verify/push are printed and skipped, which is what "dry run by default" means.
#
# The primary carried other lanes' in-flight runtime files for the whole release lane, so
# this retries: any window where `git status` shows no modified tracked file and no
# untracked runtime file is enough for a 3-second preflight-only plan. A run that still
# loses the race is retried with --resume-from=preflight (the state directory is
# append-only and owned by this tag).
set -u
REPO=/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port
EVID=$REPO/port/native-release-pipeline/evidence
TAG=release-pipeline-dryrun-primary-2026-09-22
STATE=/tmp/opencode/cocs-release-$TAG
mkdir -p "$EVID"

clean() {
  # Frozen = no modified/staged tracked file, and no untracked runtime file.
  # Evidence/report/handoff paths are exempt exactly as the pipeline treats them.
  git -C "$REPO" status --porcelain=v1 -uall \
    | grep -vE '^.{2} (port/handoffs/|port/[^/]+/[^/]*evidence/|reports/)' \
    | grep -q . && return 1
  return 0
}

attempts=0
wins=0
for _ in $(seq 1 360); do
  if clean; then
    attempts=$((attempts + 1))
    resume=""
    [ -f "$STATE/state.json" ] && resume="--resume-from=preflight"
    cd "$REPO"
    git rev-parse HEAD > "$EVID/dry-run-primary-head.txt"
    git status --porcelain=v1 -uall > "$EVID/dry-run-primary-status-before.txt"
    date -u +%Y-%m-%dT%H:%M:%SZ > "$EVID/dry-run-primary-started-at.txt"
    node tools/release/release.mjs --tag="$TAG" $resume > "$EVID/dry-run-primary-console.log" 2>&1
    code=$?
    echo "$code" > "$EVID/dry-run-primary-exit-code.txt"
    echo "$attempts" > "$EVID/dry-run-primary-attempts.txt"
    if [ "$code" -eq 0 ]; then
      wins=1
      break
    fi
  fi
  sleep 10
done
if [ "$wins" -eq 1 ]; then
  mkdir -p "$EVID/dry-run-primary-state-runs"
  tar -C "$STATE/runs" --exclude='*/runtime' -cf - . | tar -C "$EVID/dry-run-primary-state-runs" -xf -
  git -C "$REPO" status --porcelain=v1 -uall > "$EVID/dry-run-primary-status-after.txt"
  date -u +%Y-%m-%dT%H:%M:%SZ > "$EVID/dry-run-primary-finished-at.txt"
  echo done > "$EVID/dry-run-primary-status.txt"
else
  echo "no frozen window within the wait budget after $attempts attempt(s)" > "$EVID/dry-run-primary-status.txt"
fi
