#!/usr/bin/env bash
set -euo pipefail

# Ensure git repo
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Not inside a git repository."
  exit 1
fi

ROOT=$(git rev-parse --show-toplevel)
cd "$ROOT"

mkdir -p .github
cat > .github/pull_request_template.md <<'EOF'
# Summary
- 

# Changes
- 

# Testing
- [ ] Not run (explain why)
- [ ] Unit tests
- [ ] UI tests

# Checklist
- [ ] Self-reviewed
- [ ] No secrets or keys added
- [ ] Screenshots (if UI changes)
EOF

echo "Wrote .github/pull_request_template.md"
