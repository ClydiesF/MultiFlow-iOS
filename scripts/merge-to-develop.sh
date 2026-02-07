#!/usr/bin/env bash
set -euo pipefail

# Ensure git repo
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Not inside a git repository."
  exit 1
fi

ROOT=$(git rev-parse --show-toplevel)
cd "$ROOT"

CURRENT=$(git branch --show-current)
if [ "$CURRENT" = "develop" ]; then
  echo "You are already on develop. Merge a feature branch into develop from a feature branch."
  exit 1
fi

# Update develop
git fetch origin develop
git checkout develop
git pull --ff-only origin develop

# Merge current branch
FEATURE="$CURRENT"
git merge --no-ff "$FEATURE" -m "Merge $FEATURE into develop"

git push origin develop

echo "Merged $FEATURE into develop and pushed."
