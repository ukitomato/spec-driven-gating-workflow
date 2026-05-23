# Frontmatter & Body Meta Handling Matrix

> Spec-Driven Gating Workflow の全 subagent / orchestrator が **frontmatter キーと body marker の許容範囲** を一元参照するための SSoT (Wave 5 follow-up 2026-05-23、resolves #18)。
>
> 旧設計では各 subagent (charter-drafter / spec-reverser / glossary-extractor / constitution-drafter) が個別に "ここでは confidence: を許容" "story_type: は不可" を判断していたため、subagent 間で微妙にズレが発生していた。本 file を SSoT とすることで、全 subagent が同じ matrix を参照する。

## 1. Frontmatter キー許容マトリクス

各 artifact file に書ける frontmatter キーの **whitelist** (本表に無いキーは禁止)。

### 1.1 Final SSoT (Phase 6 finalize 後の本体 file)

| Artifact | 必須キー | 任意キー | 禁止キー |
|---|---|---|---|
| `docs/discovery.md` | `status` | `last_updated` | `generated_by`, `generated_at`, `confidence` |
| `docs/domains/<name>/charter.md` | `status` | `feature_status`, `last_updated` | `generated_by`, `confidence`, `story_type`, `needs_human_review` |
| `docs/domains/_overview.md` | `status` | `last_updated` | `generated_by`, `confidence` |
| `.specify/memory/constitution.md` | `status`, `version`, `ratified_at`, `last_amended_at` | `stack` | `generated_by`, `confidence`, `bad_pattern_grep`, `existing_violations` (→ `.specify/principle-baseline.yml`) |
| `docs/glossary.md` | `status` | `last_updated` | `generated_by`, `confidence`, `sources`, `approved_at` |
| `specs/<NNN>/spec.md` | (なし、bold-field metadata 使用が推奨) | `linear` | `confidence`, `story_type`, `needs_human_review`, `bf_ids`, `sf_ids`, `generated_by` |
| `specs/<NNN>/plan.md` | (なし) | `linear` | `confidence`, `story_type`, `needs_human_review`, `bf_ids`, `sf_ids`, `generated_by` |
| `specs/<NNN>/tasks.md` | `description` | — | `confidence`, `story_type`, `needs_human_review`, `bf_ids` (→ trace), `sf_ids` (→ trace) |
| `specs/<NNN>/research.md` | (なし、bold-field) | `confidence` (low\|medium\|high) | `story_type` (use body 3-tag instead) |
| `specs/<NNN>/data-model.md` | (なし) | — | 同上 |
| `specs/<NNN>/quickstart.md` | (なし) | — | 同上 |
| `specs/<NNN>/contracts/*.md` | (なし) | — | 同上 |

### 1.2 Migration trace (Phase 6 で隔離される作業メタ)

| Artifact | 必須キー | 任意キー |
|---|---|---|
| `.<stem>.migration-trace.md` (per-artifact) | `trace_type`, `generated_by`, `generated_at` | `source`, `purpose` |
| `specs/<NNN>/.migration-trace.md` (per-spec) | `trace_type`, `generated_by`, `generated_at`, `spec_id` | `domain`, `source`, `purpose` |

trace file 内では **すべて許容**: `confidence:`, `story_type:`, `bf_ids:`, `sf_ids:`, `[observed]` 等。

### 1.3 Live data (作業 SSoT、Phase 6 finalize の対象外)

| Artifact | 必須キー | 任意キー |
|---|---|---|
| `.specify/principle-baseline.yml` | `version`, `principles`, `summary` | `generated_at`, `last_updated` |
| `.specify/cdi.yml` | `version`, `cdis`, `summary` | `generated_at`, `last_updated` |
| `.specify/.id-registry.json` | `version`, `bf_next`, `sf_be_next`, `sf_fe_next`, `allocated` | — |
| `.specify/.migrate-progress.json` | `version`, `started_at`, `prefix`, `phases`, `next_actions` | — |
| `.specify/.agents-registry.yaml` | `version`, `agents` | `external_agents`, `disabled_optional_reviewers` |

## 2. Body marker 許容マトリクス

各 file の **body** (Markdown 本文) に書ける marker。

| Marker | Final SSoT | research.md | .migration-trace.md | 備考 |
|---|---|---|---|---|
| `[observed]` | ❌ | ✅ | ✅ | brownfield 観察事実 |
| `[aspiration]` | ❌ | ✅ | ✅ | 宣言意図、未実装 |
| `[NOT-observed]` | ❌ | ✅ | ✅ | 期待されるが evidence なし |
| `(推定)` | ❌ | ❌ | ❌ | **全 file 禁止** (旧マーカー、3-tag に置換) |
| `path:line` 引用 (`apps/foo.ts:42`) | ❌ | ✅ | ✅ | code 由来引用 |
| クラス名 / 関数名 直接引用 | ❌ | ✅ | ✅ | 業務用語を優先 |
| Disclaimer phrases (※下表) | ❌ | ✅ (限定) | ✅ | "本書は逆生成された" 等 |

### Disclaimer phrases (`spec-reverser` Pre-output Style Guard の禁止対象)

| Phrase | 禁止される場所 |
|---|---|
| "Migrated from existing implementation" | Final SSoT 全 file 本文 |
| "本書は既存コードと git 履歴から逆生成された" | Final SSoT 全 file 本文 |
| "Recovered from code observation" | Final SSoT 全 file 本文 |
| "This document records OBSERVED BEHAVIOR, NOT user research" | Final SSoT 全 file 本文 |
| "Plan reverse-engineered from existing implementation" | Final SSoT 全 file 本文 |
| "Validate against current architecture" | Final SSoT 全 file 本文 |
| "spec-reverser が生成" | Final SSoT 全 file 本文 |
| "All tasks are pre-checked since the feature is already implemented" | Final SSoT 全 file 本文 |

trace file / HTML comment (`<!-- ... -->`) 内なら上記いずれも OK。

## 3. Self-check procedure (各 subagent が draft return 直前に実行)

```text
For each file being returned as draft:
  1. Read file content (frontmatter + body)
  2. Identify file type by path → look up section 1 row
  3. Frontmatter check:
     - 必須キーすべて存在? → なければ追加
     - 禁止キー存在? → 該当キーを削除 (本来の保管先は section 1 の備考列を参照)
     - 任意キー以外で許容外のキー存在? → 警告
  4. Body marker check:
     - section 2 の "Final SSoT" 列で ❌ のマーカー / phrase が含まれる? → 削除 (適切な代替表現に rewrite)
  5. すべて pass → invoker に return
  6. 1+ FAIL → 該当 file を rewrite してから return
```

## 4. verify が読む section

`/spec-gate verify` Phase 2.6 (finalize-cleanliness check) は本 file の section 1 / 2 を参照して機械検証する。subagent と verify が **同じ matrix** を見ることで、subagent が pass させた draft が verify で fail する drift を防ぐ。

## 5. 改定手順

本 matrix の変更は workflow 自体の design change なので慎重に:

1. 変更提案を `.specify/decisions/<NNNN>-meta-handling-update.md` (workflow 側) として作成
2. 影響を受ける subagent (charter-drafter / spec-reverser / glossary-extractor / constitution-drafter / phase-6-finalizer) の self-check 実装を同時に更新
3. verify の Phase 2.6 / 4.7 ロジックを同時に更新
4. CHANGELOG.md に Breaking change として記録

## 6. 既知の非対称性

- `linear:` キーは spec.md / plan.md の任意キーだが、SpecKit standard が定義 (project tracker 連動)
- `feature_status: pending` は meeting / 将来機能 charter で許可 (Menteech pilot 由来、`docs/domains/meeting/charter.md` で実例)
- `last_updated:` は人間運用の任意キーで、CI で自動更新する project もある (本 matrix は強制しない)
