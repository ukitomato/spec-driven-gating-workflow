---
name: {{prefix}}-design-gate
description: Design Phase 末尾の hard gate。spec.md + plan.md + tasks.md (+ data-model.md / research.md / contracts/) を bundle で検証する。`/speckit.analyze` (machine consistency) + `po-reviewer` (User Story 価値) + `architecture-reviewer` (Constitution / Charter / ADR drift) の **3 並列 clean-context** 起動 → 集約 `design-gate.md`。Critical=0 で tasking → implementing 昇格。
disable-model-invocation: true
allowed-tools: Read Write Edit Bash Glob Grep Agent AskUserQuestion
---

# {{prefix}}-design-gate

Design Phase の **最後の品質ゲート**。`/{{prefix}}-implement` 起動前に手動起動する。`spec.md` + `plan.md` + `tasks.md` を **bundle で** レビューし、Critical 指摘が解消されるまで status を `tasking` から進めない。

## When to invoke

- `/{{prefix}}-tasks` 完了後、`/{{prefix}}-implement` 起動前
- `spec.md` 単体のレビューではなく、設計フェーズ全体 (spec + plan + tasks) の整合性を検証する gate

## Inputs

- `<spec_dir>` (optional): 省略時は branch 名から推定

## Steps

### Phase 0: spec_dir resolution + state check

1. spec_dir を解決 (`bash .specify/scripts/spec-resolve.sh`)
2. 以下が存在することを確認 (1 つでも欠ければ halt):
   - `<spec_dir>/spec.md`
   - `<spec_dir>/plan.md`
   - `<spec_dir>/tasks.md`
3. frontmatter `status` を読み取る:
   - `tasking` → 正常
   - `implementing` 以降 → AskUserQuestion で「再レビューしますか? (status は据置)」を確認
   - `drafting` / `planning` → halt with "/{{prefix}}-plan, /{{prefix}}-tasks を先に完了してください"
4. `domain` 値を frontmatter から取得 → `docs/domains/<domain>/charter.md` の存在を確認

### Phase 1: 3 並列 clean-context 起動

**1 つのメッセージ内で 3 つのトラックを並列起動する**。各トラックは完全独立、互いの出力を見ない。

| Track | Trigger | 観点 |
|---|---|---|
| **A. `/speckit.analyze`** | Bash で `claude --slash speckit.analyze <spec_dir>` (run_in_background=true) → 出力を `<spec_dir>/.gate-analyze.out` に保存 | **機械的 consistency**: spec / plan / tasks / contracts の identifier 整合、EARS 完全性、Constitution Article 参照 |
| **B. `po-reviewer`** | Agent ツール (`subagent_type: po-reviewer`) | **ビジネス価値**: User Story の "why" / Success Criteria の計測可能性 / Acceptance Criteria testability / UX negative cases / 優先度妥当性 |
| **C. `architecture-reviewer`** | Agent ツール (`subagent_type: architecture-reviewer`) | **アーキ整合**: Constitution Principle drift / Domain Charter drift / 関連 ADR drift / レイヤ違反 / cross-domain invariant 違反 |

各 subagent に context として渡す素材:

- `<spec_dir>/spec.md` (必須)
- `<spec_dir>/{plan.md, tasks.md, data-model.md, research.md, contracts/, quickstart.md, checklists/}` (存在分すべて)
- `docs/domains/<domain>/charter.md`
- `docs/domains/_overview.md` (存在すれば)
- `docs/glossary.md`
- `.specify/memory/constitution.md`
- `docs/decisions/*.md` で `status: accepted` のもの (header + Decision Outcome section)

**clean-context isolation の意味**: subagent は本 skill のメインスレッドの会話履歴を一切見ない。frontmatter `tools: Read, Grep, Glob` で Edit/Write も禁止 (read-only)。

3 トラックすべての完了を待機 (Bash run_in_background は完了通知を受け取る、Agent 呼び出しは tool result で同期取得)。

### Phase 2: 集約 — `<spec_dir>/design-gate.md`

```markdown
# Design Gate: <spec.md title>

**Run**: <ISO 8601>
**Spec**: specs/<spec_dir>/spec.md
**Domain**: <domain>
**Charter**: docs/domains/<domain>/charter.md
**Tracks**: /speckit.analyze, po-reviewer, architecture-reviewer (3 parallel clean-context)

## Verdict

| Track | Critical | High | Medium | Low |
|---|---|---|---|---|
| analyze        | <n> | <n> | <n> | <n> |
| po-reviewer    | <n> | <n> | <n> | <n> |
| architecture-reviewer | <n> | <n> | <n> | <n> |
| **Total (dedup)** | **<N>** | <n> | <n> | <n> |

**Status**: <PASS | FIX_REQUIRED>
**Next**: <Critical=0 なら "status: tasking → implementing 昇格、/{{prefix}}-implement 起動可能" | "Fix Critical 指摘を解消してから再実行">

## Critical (Total: <N>)

### C-001 — <title> [origin: po | analyze | architecture]
- **Where**: spec.md US-2 / plan.md L42 / tasks.md SH-005
- **Issue**: <reviewer 出力をそのまま>
- **Why critical**: <根拠>
- **Action**: <修正提案>

...

## High / Medium / Low

...

## Track raw outputs

<details>
<summary>analyze.out</summary>

```
<full output>
```
</details>

<details>
<summary>po-reviewer</summary>
...
</details>
```

### Phase 3: 重複排除 (dedup)

3 トラックが同一根本原因を別 finding として上げる可能性がある。集約時に:

1. spec.md の同じ行 / Section / SC-NNN ID に紐づく Critical/High はマージ候補
2. AskUserQuestion でユーザに「同根本原因なら 1 件に集約しますか?」を提示 (or `--auto-dedup` で LLM 判断)
3. dedup 結果を Total 行に反映

### Phase 4: Status 遷移判定

```
Critical (dedup後) == 0:
  - spec.md frontmatter `status:` を tasking → implementing に Edit
  - design-gate.md の Status に "PASS" を記録
  - 次のアクション案内: /{{prefix}}-implement <spec_dir>

Critical > 0:
  - status は変更しない (tasking 据置)
  - design-gate.md の Status に "FIX_REQUIRED" を記録
  - 次のアクション案内: "spec.md / plan.md / tasks.md を修正後、/{{prefix}}-design-gate を再実行"
```

### Phase 5: 完了通知

```
✓ /{{prefix}}-design-gate 完了
  - spec dir: <spec_dir>
  - tracks: 3 並列 (analyze + po + architecture)
  - critical (total dedup): <N>
  - verdict: <PASS|FIX_REQUIRED>
  - status: <tasking → implementing | tasking 据置>
```

## Idempotency

- 同一 spec_dir で再実行可能 (毎回 design-gate.md を新規生成、過去版は `design-gate.md.<TS>` に rename して保存)
- status が `implementing` 以降でも再レビュー可 (status は変更しない)

## Failure modes

- `/speckit.analyze` の subprocess 失敗 → track A だけ skip + warning、track B/C の結果で判定
- subagent エラー (timeout / context overflow) → 当該 track 単独で retry 1 回、再失敗時は track 単位で skip 表示
- 全 track 失敗 → halt (status 変更なし)
- domain charter missing → halt

## Acceptance criteria

1. `<spec_dir>/design-gate.md` が存在
2. 3 トラックの出力が記録されている (skip された track は明示)
3. Verdict が PASS か FIX_REQUIRED で明記
4. Critical 件数が dedup 後の値で表示
5. PASS の場合のみ spec.md frontmatter `status:` が `implementing` に遷移
6. design-gate.md に subagent の raw output が `<details>` 内に保存されている
