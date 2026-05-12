#!/usr/bin/env bash
# Compare two sorry manifests (base vs head) and report newly introduced
# sorry-tainted declarations as a GitHub Actions Job Summary and PR comment.
#
# Usage:
#   bash scripts/sorry-diff.sh <base-manifest> <head-manifest>
#
# Environment variables (set by CI):
#   GITHUB_STEP_SUMMARY  — path to the job summary file
#   GITHUB_REPOSITORY    — owner/repo
#   GITHUB_TOKEN         — token with pull-requests:write
#   PR_NUMBER            — pull request number
#   SORRY_FAIL_ON_NEW    — if "true", exit 1 when new sorries are found
set -euo pipefail

BASE="${1:-}"
HEAD="${2:-}"

if [ -z "$HEAD" ] || [ ! -f "$HEAD" ]; then
  echo "Error: head manifest not found at '${HEAD}'" >&2
  exit 1
fi

total=$(wc -l < "$HEAD" | tr -d ' ')

if [ -n "$BASE" ] && [ -f "$BASE" ]; then
  has_baseline=true
  new_lines=$(comm -13 <(LC_ALL=C sort "$BASE") <(LC_ALL=C sort "$HEAD") || true)
  if [ -z "$new_lines" ]; then
    new_count=0
  else
    new_count=$(printf '%s\n' "$new_lines" | wc -l | tr -d ' ')
  fi
else
  has_baseline=false
  new_count=0
  new_lines=""
fi

# ── Build Markdown body ────────────────────────────────────────────────
marker="<!-- sorry-delta-bot -->"
body="$marker"$'\n'"### Sorry Delta"$'\n\n'

if [ "$has_baseline" = false ]; then
  body+="No baseline available for comparison. Current sorry-tainted declarations: ${total}"
elif [ "$new_count" -eq 0 ]; then
  body+="No new sorry-tainted declarations introduced. (${total} total)"
else
  body+="**${new_count} new sorry-tainted declaration"
  [ "$new_count" -gt 1 ] && body+="s"
  body+="** (${total} total)"$'\n\n'
  body+="| Module | Declaration | Kind |"$'\n'
  body+="|--------|-------------|------|"$'\n'

  shown=0
  max_rows=50
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    if [ "$shown" -ge "$max_rows" ]; then
      break
    fi
    mod=$(echo "$line" | awk '{print $1}')
    decl=$(echo "$line" | awk '{print $2}')
    kind=$(echo "$line" | awk '{print $3}')
    body+="| ${mod} | \`${decl}\` | ${kind} |"$'\n'
    shown=$((shown + 1))
  done <<< "$new_lines"

  remaining=$((new_count - shown))
  if [ "$remaining" -gt 0 ]; then
    body+=$'\n'"... and ${remaining} more (see full manifest in job log)"
  fi
fi

# ── GitHub Step Summary ────────────────────────────────────────────────
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  echo "$body" >> "$GITHUB_STEP_SUMMARY"
fi

# ── Upsert PR comment ─────────────────────────────────────────────────
if [ -n "${PR_NUMBER:-}" ] && [ -n "${GITHUB_REPOSITORY:-}" ]; then
  existing=$(gh api "repos/${GITHUB_REPOSITORY}/issues/${PR_NUMBER}/comments" \
    --jq '.[] | select(.body | contains("<!-- sorry-delta-bot -->")) | .id' 2>/dev/null \
    | head -1 || true)
  if [ -n "$existing" ]; then
    gh api "repos/${GITHUB_REPOSITORY}/issues/${PR_NUMBER}/comments/${existing}" \
      -X PATCH -f body="$body" > /dev/null
  else
    gh pr comment "$PR_NUMBER" --body "$body" > /dev/null
  fi
fi

# ── Console summary ───────────────────────────────────────────────────
echo "--- Sorry Delta Summary ---"
echo "Total sorry-tainted: $total"
if [ "$has_baseline" = true ]; then
  echo "New in this PR: $new_count"
fi

# ── Opt-in failure on new sorries ─────────────────────────────────────
if [ "${SORRY_FAIL_ON_NEW:-}" = "true" ] && [ "$new_count" -gt 0 ]; then
  echo "::error::${new_count} new sorry-tainted declaration(s) introduced"
  exit 1
fi
