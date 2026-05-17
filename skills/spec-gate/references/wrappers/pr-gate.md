---
name: {{prefix}}-pr-gate
description: PR 提出前の adversarial review gate。`git diff <base>...HEAD` 全体を 5+3 並列 reviewer (security/architecture/perf/adr-drift + system scope) で検証。multi-round adversary review (Round N-1 引継ぎ、Round ≥4 で convergence gate)。Critical=0 で /{{prefix}}-done を許可。
disable-model-invocation: true
allowed-tools: Read Write Edit Bash Glob Grep Agent AskUserQuestion
---

# {{prefix}}-pr-gate

PR 提出前の **adversarial review gate**。`/{{prefix}}-code-gate` PASS 後に手動起動する。`git diff <base>...HEAD` 全体を **5+3 並列 reviewer 上限** で多角的にレビューし、Critical 指摘が解消されるまで `/{{prefix}}-done` を許可しない。

## When to invoke

- `/{{prefix}}-code-gate` PASS 後 (status: reviewing)
- 反復: 同 PR で複数 round。Round N-1 の findings を引き継いで N で再評価

## Inputs

- `<spec_dir>` (optional): 省略時 branch 名から推定
- `--base <branch>` (default: `develop` or `main` — `.specify/config.yaml` から取得): diff の基準
- `--defer-remaining`: Tier 2 deferral (一部 Critical/High を follow-up Issue として punt)
- `--round <N>`: 明示的に round 番号を指定 (省略時は既存 pr-gate.md から推定 + 1)

## Steps

### Phase 0: Preconditions

1. spec_dir 解決
2. `spec.md` frontmatter `status: reviewing` を確認 (異なれば halt with "/{{prefix}}-code-gate PASS 後に")
3. `<spec_dir>/code-gate.md` の最終 verdict が PASS であることを確認
4. base branch (`develop` / `main`) と現在 branch の関係を確認 (`git merge-base --is-ancestor` で diverge 確認)

### Phase 1: Round 番号の決定 + 前 round 引継ぎ

1. `<spec_dir>/pr-gate.md.round*` の存在を Glob、最大 round 番号を取得
2. `--round` 指定があればそちらを優先
3. 新規 round 番号 N = (既存最大 + 1) または `--round` 指定値
4. N >= 2 の場合、`pr-gate.md.round<N-1>` の **Critical/High findings + status** を Read し subagent context に含める

### Phase 2: Convergence gate (N >= 4 の時のみ)

Round 4 以降は **convergence failure** をチェック:

```
直近 2 round (N-1, N-2) の比較:
  resolved_count = findings status: resolved の数 (Round N-1 で resolved とマークされた件)
  new_findings   = findings status: new の数 (Round N-1 で新規発見)
  
  IF resolved < new (2 round 連続):
    halt with "Convergence failure: 修正のたびに新規 finding が増加しています。
              ADR-0018 (convergence rules) に基づき manual intervention を推奨。
              --defer-remaining で残 Critical を follow-up Issue 化して進める選択肢あり"
```

ユーザが `--defer-remaining` を指定していれば skip。

### Phase 3: Reviewer 選定 (feature scope + system scope)

**feature scope reviewer (常駐 5)**:

- `security-reviewer`
- `architecture-reviewer`
- `api-performance-reviewer` (存在すれば)
- `architecture-reviewer` の ADR drift モード (`--scope adr-drift`)
- `convention-reviewer`

**system scope reviewer (file pattern 連動、最大 +3)**:

`git diff --name-only <base>...HEAD` から file pattern を判定し動的に追加:

| Pattern | 追加 reviewer |
|---|---|
| `**/migrations/**` or `*.sql` | `database-reviewer` |
| `openapi.yaml` or `**/contracts/*.yaml` | `openapi-contract-reviewer` |
| `**/*.tsx`, `**/*.vue`, `**/*.dart` (UI files) | `ux-reviewer` / `a11y-reviewer` |

合計 5+3 = 最大 8 reviewer 並列。

### Phase 4: 並列起動

1 message 内で全 reviewer を並列 Agent 起動 (clean-context isolation)。各 subagent に渡す context:

- `<spec_dir>/{spec,plan,tasks,design-gate,code-gate}.md` (前段の判断材料)
- `git diff <base>...HEAD` の full diff (50KB 超なら `--stat` + 重要ファイルのみ)
- `<spec_dir>/touched-files.txt`
- `.specify/memory/constitution.md`
- `docs/domains/<domain>/charter.md`
- `docs/decisions/*.md` (status: accepted)
- (N >= 2 のとき) Round N-1 の Critical/High findings 一覧

### Phase 5: 集約 — `<spec_dir>/pr-gate.md.round<N>`

```markdown
# PR Gate Round <N>: <spec.md title>

**Run**: <ISO>
**Base**: <base branch>
**Diff stat**: +<L> -<M> over <K> files
**Reviewers**: <list>
**Round inheritance**: Round <N-1> findings (Critical: <X>, High: <Y>) を引継ぎ

## Verdict

| Severity | This round | Resolved from N-1 | New in N | Net |
|---|---|---|---|---|
| Critical | <n> | <r> | <new> | <n> |
| High     | ... |
| Medium   | ... |
| Low      | ... |

**Status**: <PASS (Critical=0) | FIX_REQUIRED | CONVERGENCE_FAILURE (N>=4)>
**Next**:
  PASS         → /{{prefix}}-done <spec_dir>
  FIX_REQUIRED → コード修正 + /{{prefix}}-pr-gate 再実行 (Round <N+1>)
  CONVERGENCE  → ADR 起票 + manual review or --defer-remaining

## Critical (Round <N>)

### C-001 — <title> [origin: security | architecture | ...]
- **Where**: <file:line, ...>
- **Issue**: ...
- **Why critical**: ...
- **Suggested fix**: ...
- **Status in this round**: new | resolved from N-1 | unresolved from N-1

...

## Track raw outputs

<details>...
```

### Phase 6: Dedup + 重複 finding の検出

複数 reviewer が同一根本原因を上げる可能性 → AskUserQuestion で merge 提案 (or `--auto-dedup`)。

### Phase 7: `--defer-remaining` 時の処理 (任意)

ユーザが `--defer-remaining` を指定し、Critical が残っている場合:

1. AskUserQuestion で defer する Critical/High を選択
2. 選択された findings を follow-up Issue として書き出し (`<spec_dir>/deferred-findings.md`)
3. ユーザに「GitHub Issue / Linear Issue を作成してから本 round を PASS とする」よう案内
4. Verdict を "PASS (with deferred)" に更新

### Phase 8: 完了通知

```
✓ /{{prefix}}-pr-gate Round <N> 完了
  - spec dir: <spec_dir>
  - reviewers: <count> 並列
  - critical (net): <N>
  - verdict: <PASS | FIX_REQUIRED | CONVERGENCE_FAILURE>
  - 次のアクション:
    PASS → /{{prefix}}-done <spec_dir>
    FIX_REQUIRED → 修正後 /{{prefix}}-pr-gate (Round <N+1>)
```

Status は変更しない (`reviewing` 据置)。`/{{prefix}}-done` が完了時に `reviewing → completed` 遷移。

## Idempotency

- 各 round の出力は `pr-gate.md.round<N>` に保存、最新を `pr-gate.md` symlink (or copy)
- 同 round 番号で再実行されたら overwrite (with `.bak`)

## Failure modes

- subagent timeout → 当該 reviewer track のみ skip + warning
- 全 reviewer 失敗 → halt
- convergence failure (N >= 4) → halt with manual intervention 案内
- diff が空 → halt with "実装変更がありません"
- base branch が不明 → AskUserQuestion で指定を求める

## Acceptance criteria

1. `<spec_dir>/pr-gate.md.round<N>` が存在
2. Verdict が PASS / FIX_REQUIRED / CONVERGENCE_FAILURE のいずれかで明記
3. N >= 2 の場合、Round N-1 からの引継ぎ (resolved / unresolved / new) がテーブルで表示
4. N >= 4 で convergence check が走った形跡が記録 (PASS でも CONVERGENCE_FAILURE でも明示)
5. spec.md frontmatter `status` は変更されない (`reviewing` のまま)
