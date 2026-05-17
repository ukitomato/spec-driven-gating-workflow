# /spec-gate migrate — subcommand body

> Loaded by `skills/spec-gate/SKILL.md` (dispatcher) when the first argument is `migrate`.

既存リポジトリを **Spec-Driven Gating Workflow** に乗せるための 5-phase orchestrator。各 phase で brownfield specialist subagent を clean-context で起動し、その出力を AskUserQuestion でユーザに承認させながら、最終的に `docs/discovery.md` / `docs/domains/<name>/charter.md` / `specs/rev-*/{spec,plan,tasks}.md` / `.specify/memory/constitution.draft.md` / `docs/glossary.md` を produce する。

## When to invoke

- Brownfield repo に Spec-Driven Gating Workflow を **初導入** する 1 回目
- 一部 domain だけ追加で migrate する時 (`--domains <list>`)
- 中断後の再開 (`--resume-from <phase>`)

Greenfield (新規 repo) では本 skill は不要。`/{{prefix}}-spec` から直接開始可能。

## Inputs / Flags

| Flag | 効果 |
|---|---|
| (none) | Phase 1-5 全実行 |
| `--no-reverse` | Phase 3 (Spec Reverse) を skip。governance + charter のみ整備 |
| `--no-constitution` | Phase 4 (Constitution Draft) を skip。後で `/speckit.constitution` で別途 finalize |
| `--domains a,b,c` | 指定した domain だけ Phase 2-3 を実行 |
| `--resume-from <N>` | Phase N から再開 (1-5)、それ以前の成果物は再利用 |
| `--force` | 既存 `docs/discovery.md` 等を上書き |

## Steps

### Phase 0: Preconditions + SubAgent 配置

1. `.specify/` ディレクトリ存在を確認 (なければ "Run `specify init` first" で halt)
2. `.claude/skills/<existing-prefix>-spec/` 存在を確認 (なければ "/spec-gate bootstrap を先に実行してください" で halt)
3. **brownfield specialist SubAgent を `.claude/agents/` に Write** (bootstrap で配置されていない 5 agents を補完):
   - `${CLAUDE_SKILL_DIR}/references/subagents/discovery-scanner.md` → `.claude/agents/discovery-scanner.md` (既存ならば skip)
   - `${CLAUDE_SKILL_DIR}/references/subagents/charter-drafter.md` → `.claude/agents/charter-drafter.md`
   - `${CLAUDE_SKILL_DIR}/references/subagents/spec-reverser.md` → `.claude/agents/spec-reverser.md`
   - `${CLAUDE_SKILL_DIR}/references/subagents/constitution-drafter.md` → `.claude/agents/constitution-drafter.md`
   - `${CLAUDE_SKILL_DIR}/references/subagents/glossary-extractor.md` → `.claude/agents/glossary-extractor.md`
4. `${CLAUDE_SKILL_DIR}/references/subagents/reviewer-base.md` が `.claude/agents/` にあることを確認 (bootstrap が配置済の想定、無ければ Write)
5. `.git/` がない場合は warning (commit history が読めないため Phase 1, 3 で機能制限)
6. `--resume-from` 指定があれば該当 phase の前 phase 成果物 (例 `--resume-from 3` なら `docs/domains/*/charter.md`) が存在することを確認

### Phase 1: Surface Scan

> Skip 条件: `--resume-from >= 2`

1. `discovery-scanner` subagent を Agent ツールで起動
2. tool result で受け取った draft を Read
3. `docs/discovery.md` が既存:
   - `--force` 指定なし → AskUserQuestion で「上書き / merge / skip」
   - 指定あり → 上書き
4. **AskUserQuestion** で draft をユーザに提示し、承認 / 編集 / 拒否を選択
5. 承認後 `docs/discovery.md` を Write
6. 完了通知: "Phase 1 完了。検出 tech stack: <list>。次に進みます (Phase 2)"

### Phase 2: Domain Charter Reverse (Charter ファースト)

> Skip 条件: `--resume-from >= 3`

1. `charter-drafter` subagent を Agent ツールで起動
   - context: Phase 1 で生成した `docs/discovery.md` + repo の dir 構造
2. tool result で受け取った proposed domains 一覧を確認
3. **各 domain について 1 つずつ AskUserQuestion**:
   - "domain `<name>` を採用しますか? (yes / modify name / merge with other / discard)"
   - "in scope / out of scope の境界は妥当か?"
   - "User Journey / 業務ルール / KPI の編集要否?"
4. 承認後 `docs/domains/<name>/charter.md` を Write (status: needs-human-review)
5. `docs/domains/_proposed.md` を写し (履歴として)
6. `docs/domains/_overview.md` に cross-domain invariants を draft (charter-drafter の report から)
7. `--domains` flag があれば指定 domain のみ承認、他は skip
8. 完了通知: "Phase 2 完了。確定 domain: <list>。次に進みます (Phase 3)"

### Phase 3: Spec Reverse

> Skip 条件: `--no-reverse` または `--resume-from >= 4`

1. 各 confirmed domain について feature 単位で `spec-reverser` を起動
2. invoker が feature の bounding box (関連ファイル list) を `spec-reverser` に渡す:
   - frontend / backend / DB の関連ファイル群を git history から抽出
   - 大きすぎる場合 (50+ files) は AskUserQuestion で分割範囲を確認
3. `spec-reverser` が spec.md / plan.md / tasks.md draft を返す
4. **各 feature ごとに AskUserQuestion**:
   - "domain `<domain>` 帰属で正しいか?"
   - "User Story の `<role>` / `<benefit>` は妥当か?"
   - "FR-NNN のうち推定が含まれるものは正しいか?"
   - "範囲外と判定した部分は実は本 feature の一部ではないか?"
5. 承認後 `specs/rev-<NNN>-<DOMSHORT>-<feature-slug>/{spec,plan,tasks}.md` を Write
6. `bf_ids` / `sf_ids` namespace を invoker が管理 (重複なし)
7. 完了通知: "Phase 3 完了。Reverse spec: <N> 件。次に進みます (Phase 4)"

### Phase 4: Constitution Draft

> Skip 条件: `--no-constitution` または `--resume-from >= 5`

1. `constitution-drafter` subagent を起動
   - context: discovery.md + 全 charters + reverse spec 5 件サンプル
2. tool result で受け取った Principle 案を確認
3. 既存 `.specify/memory/constitution.md` が存在:
   - status: active → AskUserQuestion で merge / append として扱うか確認
   - status: draft → 上書き (前回 draft を `.bak` に退避)
   - 存在しない → 新規 Write
4. **各 Principle ごとに AskUserQuestion**:
   - "Principle <I> を採用するか?"
   - "NON-NEGOTIABLE 判定は妥当か?"
   - "Verification (CI で自動検証可能か) の評価は妥当か?"
5. 承認した Principle のみで `.specify/memory/constitution.draft.md` を Write
6. ユーザに `/speckit.constitution` で正式版に昇格させる手順を案内
7. 完了通知: "Phase 4 完了。Principle 案: <N> 件。`/speckit.constitution` で finalize してください"

### Phase 5: Glossary Extraction

> Skip 条件: なし (常に実行、軽量)

1. `glossary-extractor` subagent を起動
   - context: discovery.md + charters + reverse spec
2. tool result で用語候補 + 同義異語 + 多言語混在を受け取る
3. **同義異語 / 多言語混在の各 group ごとに AskUserQuestion**:
   - "用語 X / Y / Z のうち canonical をどれにするか?"
   - "多言語混在は Constitution Principle 化するか?"
4. 既存 `docs/glossary.md` があれば差分のみ追記、なければ新規 Write
5. 完了通知: "Phase 5 完了。新規定義 <X> 件、既存更新 <Y> 件。**`/spec-gate verify` で品質検証を強く推奨**"

### Phase 6: Final summary

```
✓ /spec-gate migrate 完了

  Phase 1 (Scan): docs/discovery.md
  Phase 2 (Charter): docs/domains/<list>/charter.md (<N> domains)
  Phase 3 (Spec Reverse): specs/rev-*/{spec,plan,tasks}.md (<N> features)
                          [--no-reverse 時は skip]
  Phase 4 (Constitution): .specify/memory/constitution.draft.md
                          [--no-constitution 時は skip]
  Phase 5 (Glossary): docs/glossary.md (+<X> -<Y>)

  次のアクション:
    1. /spec-gate verify で品質検証 (必須推奨。structure / consistency / gap / dev-ready)
    2. 全 charter を人間レビューして status を active に
    3. constitution.draft.md を /speckit.constitution で finalize
    4. Reverse spec (specs/rev-*/) の `status: migrated, needs_human_review: true` を順次レビュー
    5. 新規 feature 開発時は /<prefix>-spec から開始
```

## Idempotency

- 各 phase 完了後に内部状態 (どの phase まで完了したか) を `.specify/.migrate-progress.json` に記録
- `--resume-from` で中断後の再開 (前 phase の成果物を再利用)
- 同じ phase の再実行は AskUserQuestion で「上書き / merge / skip」を確認
- `--force` で全 phase の確認 prompt を skip して上書き

## Failure modes

- subagent timeout (大規模 repo で長時間化) → 分割して再起動を AskUserQuestion で提案
- AskUserQuestion でユーザが domain を 0 件承認 → halt with "domain を 1 件以上承認してください"
- spec-reverser の confidence が Low ばかり → AskUserQuestion で "Phase 3 を skip しますか?" を提示
- Phase 3 で feature 抽出が困難 (commit history なし、test なし) → AskUserQuestion で feature の bounding box を手動指定

## Acceptance criteria

各 phase 完了時:

1. Phase 1: `docs/discovery.md` 存在、tech stack section に少なくとも 1 件
2. Phase 2: `docs/domains/<name>/charter.md` が少なくとも 1 件、各 charter に Mission / Scope / User Journey / 業務ルール section
3. Phase 3 (skip でなければ): `specs/rev-*/spec.md` が 1 件以上、frontmatter `status: migrated`, `bf_ids`, `sf_ids`
4. Phase 4 (skip でなければ): `.specify/memory/constitution.draft.md` 存在、Principle が 1 件以上、`status: draft, needs-human-review` frontmatter
5. Phase 5: `docs/glossary.md` 存在、Ubiquitous Language section に candidate が 1 件以上
6. 全 artifact に `status: needs-human-review` または同等のレビュー必須マーカー
