#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <feature-name>"
  echo "Example: $0 add-property-photos"
  exit 1
fi

FEATURE_NAME="$1"
BRANCH="codex/$FEATURE_NAME"

# Ensure git repo
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Not inside a git repository."
  exit 1
fi

# Go to repo root
ROOT=$(git rev-parse --show-toplevel)
cd "$ROOT"

# Make sure develop exists locally
if ! git show-ref --verify --quiet refs/heads/develop; then
  echo "Local develop branch not found. Fetching..."
  git fetch origin develop:develop
fi

# Update develop
git checkout develop
git pull --ff-only origin develop

# Create branch
if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
  echo "Branch $BRANCH already exists."
  exit 1
fi

git checkout -b "$BRANCH"

echo "Created and switched to $BRANCH"
