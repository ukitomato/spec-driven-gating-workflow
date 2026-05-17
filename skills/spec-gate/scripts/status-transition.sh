#!/usr/bin/env bash
# status-transition.sh — spec.md frontmatter の `status:` を遷移させる helper
#
# 用途:
#   gate skill (design-gate / code-gate / pr-gate / done) と producer skill
#   (spec / plan / tasks / implement) が status lifecycle を進めるために使う。
#   遷移の正当性 (from が現状値と一致するか) を検証してから書き換える。
#
# Status lifecycle:
#   drafting → planning → tasking → implementing → reviewing → completed
#
# 使い方:
#   bash .specify/scripts/status-transition.sh <spec_dir> <from> <to>
#
#   例:
#     bash .specify/scripts/status-transition.sh specs/001-auth-login drafting planning
#     bash .specify/scripts/status-transition.sh specs/001-auth-login tasking implementing
#
# Exit:
#   0 → 遷移成功
#   1 → 現状値が <from> と不一致 (遷移を中止)
#   2 → 引数不足 / spec.md 不存在 / parse 失敗

set -euo pipefail

spec_dir="${1:?usage: status-transition.sh <spec_dir> <from> <to>}"
expected_from="${2:?expected current status required}"
new_to="${3:?new status required}"

spec_file="${spec_dir}/spec.md"

if [ ! -f "$spec_file" ]; then
  echo "status-transition: spec.md not found at $spec_file" >&2
  exit 2
fi

# Valid statuses
VALID_STATUSES=("drafting" "planning" "tasking" "implementing" "reviewing" "completed" "migrated")

is_valid_status() {
  local s="$1"
  for v in "${VALID_STATUSES[@]}"; do
    [ "$s" = "$v" ] && return 0
  done
  return 1
}

if ! is_valid_status "$expected_from"; then
  echo "status-transition: invalid 'from' status '$expected_from'" >&2
  echo "  Valid: ${VALID_STATUSES[*]}" >&2
  exit 2
fi

if ! is_valid_status "$new_to"; then
  echo "status-transition: invalid 'to' status '$new_to'" >&2
  echo "  Valid: ${VALID_STATUSES[*]}" >&2
  exit 2
fi

# frontmatter から現状の status を抽出
# (---で挟まれた YAML 領域内の `status:` 行を最初の1件だけ)
current=$(awk '/^---$/{c++} c==1 && /^status:[[:space:]]*/{
  sub(/^status:[[:space:]]*/, "")
  # quotes と末尾空白を除去
  gsub(/^["'\'']|["'\'']$/, "")
  gsub(/[[:space:]]+$/, "")
  print
  exit
}' "$spec_file")

if [ -z "$current" ]; then
  echo "status-transition: cannot find 'status:' in frontmatter of $spec_file" >&2
  exit 2
fi

if [ "$current" != "$expected_from" ]; then
  echo "status-transition: refusing to transition." >&2
  echo "  spec_file: $spec_file" >&2
  echo "  expected from: $expected_from" >&2
  echo "  actual current: $current" >&2
  echo "  to: $new_to" >&2
  exit 1
fi

# 書き換え (BSD/GNU sed compatible: use awk for safety)
tmpfile=$(mktemp)
trap 'rm -f "$tmpfile"' EXIT

awk -v new_status="$new_to" '
  BEGIN { in_fm = 0; replaced = 0 }
  /^---$/ {
    in_fm++
    print
    next
  }
  in_fm == 1 && !replaced && /^status:[[:space:]]*/ {
    print "status: " new_status
    replaced = 1
    next
  }
  { print }
' "$spec_file" > "$tmpfile"

mv "$tmpfile" "$spec_file"

echo "status-transition: $spec_file: $current → $new_to"
