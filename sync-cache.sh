#!/usr/bin/env bash
# sync-cache.sh — copy SOURCE (this repo) into the active install cache.
#
# WHY THIS EXISTS
# The plugin installs by COPYING source → ~/.claude/plugins/cache/<repo>/<plugin>/<version>/.
# It is a version-keyed copy, NOT a symlink. Two consequences:
#   - Editing the CACHE is lost on the next reinstall.
#   - Editing the SOURCE does not reach a running Claude session until reinstall.
# That is the drift that made components "keep going missing" (diagnosed 2026-07-13).
#
# THE RULE: edit the SOURCE. The cache is disposable. This script pushes source → cache
# so you can iterate without a full reinstall.
#
# Usage:  bash sync-cache.sh          # sync to the version in plugin.json
#         bash sync-cache.sh --check  # report drift, change nothing (exit 1 if drifted)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_SRC="$REPO_ROOT/plugins/raycast-extensions"
PLUGIN_JSON="$PLUGIN_SRC/.claude-plugin/plugin.json"

if [[ ! -f "$PLUGIN_JSON" ]]; then
  echo "ERROR: plugin.json not found at $PLUGIN_JSON" >&2
  exit 2
fi

# Read name + version without needing jq.
VERSION="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$PLUGIN_JSON" | head -1)"
PLUGIN_NAME="$(sed -n 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$PLUGIN_JSON" | head -1)"

if [[ -z "$VERSION" || -z "$PLUGIN_NAME" ]]; then
  echo "ERROR: could not parse name/version from $PLUGIN_JSON" >&2
  exit 2
fi

CACHE_DIR="$HOME/.claude/plugins/cache/raycast-extension-workflows/$PLUGIN_NAME/$VERSION"

echo "plugin : $PLUGIN_NAME v$VERSION"
echo "source : $PLUGIN_SRC"
echo "cache  : $CACHE_DIR"
echo

# --check: report drift only. Never mutates.
if [[ "${1:-}" == "--check" ]]; then
  if [[ ! -d "$CACHE_DIR" ]]; then
    echo "DRIFT: cache dir does not exist for v$VERSION (never installed, or version was bumped)."
    echo "       Run: bash sync-cache.sh"
    exit 1
  fi
  drift=0
  for sub in reference skills; do
    if ! diff -r --brief "$PLUGIN_SRC/$sub" "$CACHE_DIR/$sub" 2>&1 | grep . ; then
      : # identical — diff printed nothing
    else
      drift=1
    fi
  done
  echo
  if [[ $drift -eq 1 ]]; then
    echo "DRIFT: source and cache differ (see above). Run: bash sync-cache.sh"
    exit 1
  fi
  echo "OK: cache matches source for v$VERSION."
  exit 0
fi

# Sync. rsync --delete so files REMOVED from source also leave the cache —
# a plain copy would leave orphans behind and reintroduce drift in the other direction.
mkdir -p "$CACHE_DIR"
for sub in reference skills; do
  rsync -a --delete "$PLUGIN_SRC/$sub/" "$CACHE_DIR/$sub/"
  echo "  synced $sub/"
done

echo
echo "Synced source → cache for v$VERSION."
echo "NOTE: a running Claude session may still hold the OLD skills in context."
echo "      Start a new session to pick these up."
