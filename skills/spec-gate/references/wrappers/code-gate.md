---
name: {{prefix}}-code-gate
description: Implementation Phase 末尾の self-review gate。working tree diff を 3-5 並列 reviewer (lint / test / convention + tech-stack 固有) で検証し、MUST_FIX があれば implementer subagent で auto-fix loop (max 3 iter、cascade exhaustion 確認)。PASS で implementing → reviewing 昇格。
disable-model-invocation: true
allowed-tools: Read Write Edit Bash Glob Grep Agent AskUserQuestion
---

# {{prefix}}-code-gate

Implementation Phase の **self-review gate**。`/{{prefix}}-implement` 完了後に auto-chain で起動される (手動起動も可)。working tree diff を **3-5 並列 reviewer** で検証し、`MUST_FIX` 指摘があれば `implementer` subagent で **auto-fix loop** を最大 3 iteration 実行。すべて解消で `implementing → reviewing` に昇格。

## When to invoke

- `/{{prefix}}-implement` から auto-chain
- 手動: 実装後の self-review を再実行したい時

## Inputs

- `<spec_dir>` (optional): 省略時 branch 名から推定
- `--max-iter N` (default: 3): auto-fix loop の最大回数
- `--no-auto-fix`: MUST_FIX を検出しても auto-fix を実行せず、findings を表示して halt

## Steps

### Phase 0: Preconditions

1. spec_dir 解決
2. `<spec_dir>/spec.md` の frontmatter `status` が `implementing` であることを確認
3. `tasks.md` の全タスクが `[x]` (implement Phase 4 検証済) であることを確認
4. `git status` で working tree に diff があることを確認 (なければ "実装すべき変更がありません" で halt)

### Phase 1: Diff scope の決定

```bash
diff_files=$(git diff --name-only HEAD)
# または touched-files.txt と突合して scope を絞る
touched_files=$(cat "$spec_dir/touched-files.txt" 2>/dev/null | sort -u)
```

reviewer に渡す scope は `diff_files ∩ touched_files` (touched-files.txt があれば intersect、なければ diff_files 全部)。

### Phase 2: tech-stack 別 reviewer の選定

`docs/discovery.md` (setup で生成) または `package.json` / `pyproject.toml` から tech stack を検出し、追加 reviewer を決定:

- **常駐 (3 reviewer)**: `lint-agent`, `test-agent`, `convention-reviewer`
- **stack 別追加 (最大 +2)**:
  - Flutter → `flutter-perf-reviewer` (存在すれば)
  - FastAPI/Django → `api-performance-reviewer` (存在すれば)
  - データベース変更を含む → `database-reviewer` (存在すれば)
  - WCAG 対応プロジェクト → `a11y-reviewer` (存在すれば)

存在しない reviewer は skip (warning なし)。`/{{prefix}}-add-reviewer` でユーザが事前追加した optional reviewer も自動で encore。

### Phase 3: 並列 reviewer 起動 (1 iteration)

**1 message 内で全 reviewer を並列 Agent 起動**:

| Track | Agent type | 観点 |
|---|---|---|
| lint-agent           | (内部) Bash で project lint コマンドを実行 (`pnpm lint`, `ruff check`, `flutter analyze` 等を `docs/discovery.md` から特定) | 静的解析、style 違反 |
| test-agent           | (内部) Bash で project test コマンドを実行 (`pnpm test`, `pytest`, `flutter test` 等) | テスト red の検出 |
| convention-reviewer  | Agent ツール | 命名 / module 配置 / 設計慣習 |
| (stack 別 +α)        | Agent ツール | tech-stack 固有 |

各 reviewer に context として渡す:

- `<spec_dir>/{spec,plan,tasks}.md`
- diff scope のファイル一覧
- `git diff HEAD` の full diff (大きすぎる場合は `git diff --stat` + 個別 file の diff)
- `.specify/memory/constitution.md`
- `docs/domains/<domain>/charter.md`

clean-context isolation。

### Phase 4: 集約 — findings の集計

```markdown
# Code Gate Iteration <N>: <spec.md title>

**Run**: <ISO>
**Spec**: specs/<spec_dir>/
**Diff scope**: <K files>, <L+/M->
**Tracks**: lint, test, convention-reviewer, <stack-specific...>

## Verdict

| Severity | Count | Where |
|---|---|---|
| MUST_FIX | <N> | <file:line, ...> |
| SHOULD_FIX | <M> | ... |
| CONSIDER | <K> | ... |

**Status**: <PASS | MUST_FIX>

## MUST_FIX findings (N)

### MF-001 — <title> [origin: lint | test | convention | <stack>]
- **Where**: <file:line>
- **Issue**: ...
- **Why must-fix**: ...
- **Suggested fix**: ...

...
```

### Phase 5: Auto-fix loop (MUST_FIX > 0 かつ `--no-auto-fix` でないとき)

```
for iter in 1..max_iter:
  1. implementer subagent を起動 (tools: Read, Write, Edit, Bash)
     - 入力: code-gate.md.iter<N> の MUST_FIX 一覧
     - 任務: 各 MUST_FIX を 1 つずつ修正、再実行
  2. iteration が完了したら Phase 3 から再評価 (新しい diff で reviewer 並列起動)
  3. MUST_FIX = 0 になれば break (PASS)
  4. 3 iter 連続で MUST_FIX が同じ数 / 増加していたら cascade exhaustion とみなして halt
```

**Cascade exhaustion 検出**: 修正が新しい violation を生む状況。`iter N の MUST_FIX 数 >= iter N-1` が 2 連続で発生したら halt with "Manual intervention required"。

### Phase 6: Status 遷移判定

```
PASS (MUST_FIX = 0):
  - spec.md frontmatter `status:` を implementing → reviewing に Edit
  - code-gate.md (最終 iter) に "PASS" を記録
  - 次のアクション案内: /{{prefix}}-pr-gate <spec_dir>

MUST_FIX > 0 after max_iter:
  - status は implementing 据置
  - code-gate.md に "MUST_FIX (max_iter reached)" を記録
  - 次のアクション案内: "manual fix 後に再実行 or --max-iter 値を上げて再実行"
```

### Phase 7: 完了通知

```
✓ /{{prefix}}-code-gate 完了
  - spec dir: <spec_dir>
  - iterations: <N> (auto-fix loop)
  - verdict: <PASS | MUST_FIX>
  - status: <implementing → reviewing | implementing 据置>
  - 次のアクション: /{{prefix}}-pr-gate (PASS時)
```

## Idempotency

- 再実行可能 (各 iteration を `code-gate.md.iter1`, `code-gate.md.iter2`, ..., 最終を `code-gate.md` に保存)
- 既存 `code-gate.md` は `code-gate.md.<TS>` にバックアップしてから新規生成

## Failure modes

- lint/test コマンド検出失敗 → AskUserQuestion でコマンド指定を求める
- implementer subagent の auto-fix が partial (一部 MUST_FIX しか修正しない) → 次 iter で残りに再挑戦
- cascade exhaustion → halt + 直前 iter の code-gate.md を最終とみなして表示
- git diff が空 → halt

## Acceptance criteria

1. `<spec_dir>/code-gate.md` が存在し、最終 iteration の verdict が記録
2. PASS の場合のみ spec.md frontmatter `status:` が `reviewing` に遷移
3. 各 iteration の生 output (`code-gate.md.iter<N>`) が保存されている
4. cascade exhaustion 時は halt 理由が明示
