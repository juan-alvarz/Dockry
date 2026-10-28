#!/usr/bin/env bash
# CI only: copies docs/screenshots to <branch>/ on the `screenshots` branch, which PR
# descriptions link to. Retries if another run pushed to that branch at the same time.
set -euo pipefail
cd "$(dirname "$0")/.."
branch=$1
source_dir=$PWD/docs/screenshots
worktree=$(mktemp -d)
git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

for attempt in 1 2 3; do
  rm -rf "$worktree"
  git worktree prune
  if git fetch --depth 1 origin screenshots 2>/dev/null; then
    git worktree add --detach "$worktree" FETCH_HEAD
  else
    # First use: start the branch with no history.
    git worktree add --detach "$worktree"
    git -C "$worktree" checkout -q --orphan screenshots-root
    git -C "$worktree" rm -rfq .
  fi
  rm -rf "${worktree:?}/$branch"
  mkdir -p "$worktree/$branch"
  cp "$source_dir"/*.png "$worktree/$branch/"
  git -C "$worktree" add -A
  if git -C "$worktree" diff --cached --quiet; then exit 0; fi
  git -C "$worktree" commit -qm "Screenshots for $branch"
  if git -C "$worktree" push -q origin HEAD:refs/heads/screenshots; then
    echo "Published to https://github.com/$GITHUB_REPOSITORY/tree/screenshots/$branch"
    exit 0
  fi
  echo "Push failed (attempt $attempt); retrying."
done
exit 1
