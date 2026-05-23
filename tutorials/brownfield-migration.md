# Brownfield Migration Walkthrough

既存リポジトリに Spec-Driven Gating Workflow を導入し、`/spec-gate migrate` で Charter / Spec (SpecKit 標準 7-file) / Constitution / Glossary を **逆生成** したうえで、最後に **Finalize** で作業メタを `.migration-trace.md` に隔離し、`specs/<NNN>-...` を「SpecKit 初日運用と区別がつかない状態」まで rewrite する流れ。

所要時間目安: 5-10 domain の中規模プロジェクトで約 3-5 時間 (うち 60-70% はユーザ承認の対話)。

## Prerequisites

Greenfield Walkthrough の Step 1-4 (specify init → gh skill install → /spec-gate scan → /spec-gate bootstrap) を実施済。

特に Brownfield では tech stack 検出が複雑なため、`/spec-gate scan` の出力 (`docs/discovery.md`) を **必ず人間レビュー** してから `/spec-gate bootstrap` を実行する。

## Step 1: Migrate 起動

```
/spec-gate migrate
```

引数なしで Phase 1-7 を順に実行。途中中断や特定 phase だけ走らせたい場合は flag を併用:

| Flag | 効果 |
|---|---|
| `--no-reverse` | Phase 3 (Spec Reverse) を skip。governance + charter のみ |
| `--no-constitution` | Phase 4 を skip。後で `/speckit.constitution` で別途 |
| `--domains a,b` | 特定 domain のみ Phase 2-3 を実行 |
| `--resume-from <N>` | Phase N から再開 (1-7) |
| `--skip-finalize` | Phase 6 を skip (テスト用途のみ、本番非推奨) |

## Phase 0: Preconditions + SubAgent 配置

migrate が以下を順に確認:

1. `.specify/` 存在
2. `.claude/skills/<prefix>-spec/` 存在 (bootstrap 完了の証)
3. 5 brownfield specialist SubAgent (`discovery-scanner`, `charter-drafter`, `spec-reverser`, `constitution-drafter`, `glossary-extractor`) を `.claude/agents/` に Write
4. `.git/` の存在 (commit history が読めるか)

## Phase 1: Surface Scan (約 5 分)

`discovery-scanner` subagent が起動し、tech stack を意味解析:

- 検出した build files: `package.json` / `pyproject.toml` / `pubspec.yaml` / `Cargo.toml` / `go.mod` / `pom.xml`
- 識別した framework: 例 "Vue 3 + Pinia (frontend) + FastAPI + SQLAlchemy (backend)"
- monorepo なら workspace package ごとに stack 記録
- README / CHANGELOG / `docs/` を parse

出力 draft が `docs/discovery.md` に Write されてから AskUserQuestion で提示される (Draft preview NON-NEGOTIABLE)。既存 `docs/discovery.md` (bootstrap 前の scan で生成済) があれば skip。

## Phase 2: Domain Charter Reverse (約 30-60 分、ここが最重要)

`charter-drafter` subagent が起動し、ディレクトリ構造 + URL path + テーブル prefix から domain 境界候補を抽出。

例: typical web app は以下のような proposed domain を出す:

```
| # | Domain (proposed) | Source | Confidence |
|---|---|---|---|
| 1 | auth | /api/auth/*, app/auth/, db.auth_* | High |
| 2 | users | /api/users/*, app/users/ | High |
| 3 | posts | /api/posts/*, app/posts/, db.posts_* | High |
| 4 | notifications | /api/notif/*, app/notifications/ | Medium |
| 5 | admin | /admin/*, app/admin/ | High |
```

各 domain について Mission / Scope / User Journey / 業務ルール / KPI の **draft** が `docs/domains/<name>/charter.md` に Write される (Phase 6 で finalize 予定の working draft、`status: needs-human-review`)。

**各 domain を 1 つずつ AskUserQuestion で承認**:

- 採用 / 統合 / 分割 / 拒否
- in scope / out of scope の境界調整
- User Journey の追記
- 業務ルールの修正
- KPI の measurable 化

`docs/domains/_overview.md` に cross-domain invariants (CDI) も draft され、各 CDI に `owner: undecided` のものは AskUserQuestion で owner を確定。

**この phase の品質が後続 phase の品質を決める** ので、対話に時間をかける。

## Phase 3: Spec Reverse (約 60-90 分)

`--no-reverse` を指定しなければ実行される。本 Phase は **enumeration → batch write → batch review** の 3-step 構成 (resolves "一部しか作られない" 問題):

### Phase 3.0: Feature enumeration

charter の User Journey + git log + dir structure の 3 source から candidate feature を網羅的に列挙、AskUserQuestion (multi-select、default 全選択) で対象を確定。

### Phase 3.1: Batch spec-reverser invocation

各 feature について `spec-reverser` を起動し、**SpecKit 標準 7-file** で draft を Write:

```
specs/rev-001-AUT-signup/
├── spec.md          # User Stories with priority (P1/P2/...) + Acceptance Scenarios (Given/When/Then) + System MUST FR + measurable SC + Assumptions (forward-looking、brownfield 証跡 NG)
├── plan.md          # Technical Context + Constitution Check + Project Structure + Complexity Tracking
├── research.md      # brownfield 証跡の集約場 (現状実装調査 + file:line + 3-tag marker + confidence frontmatter)
├── data-model.md    # Entity 定義 (実装非依存)
├── quickstart.md    # Acceptance Scenario の手動検証手順
├── contracts/       # API contract (1 file 以上)
│   └── <api>.md
└── tasks.md         # forward-looking のみ (Phase 1 Setup → Phase 2 Foundational → US1..N → Polish)、過去 task の [x] リスト禁止
```

**重要 (旧版からの change)**:

- spec.md / plan.md / tasks.md は **forward-looking** (SpecKit 通常 spec と同じ流儀)。3-tag marker (`[observed]` / `[aspiration]` / `[NOT-observed]`) や file:line 引用は本ファイル本体に **書かない**
- 旧版で全タスクを `[x] checked` でリストしていた tasks.md は **禁止**。tasks は今後着手する work item のみ (`/speckit-implement` 等の下流互換性)
- brownfield 証跡 (file:line / 3-tag / 旧仕様 / git commit hash) は **research.md にのみ集約**
- frontmatter の `confidence` / `story_type` は spec.md / plan.md / tasks.md には書かず、research.md frontmatter のみで保持

### Phase 3.2-3.3: Coverage validation + batch review

全 feature 書き出し後、7-file 全揃いを Bash で機械検証 → AskUserQuestion 1 回で全 feature の path list を提示し、(a) batch approve / (b) 個別 rework / (c) edit & resume / (d) reject all を選ぶ。**per-feature では halt しない**。

`rev-` prefix で物理分離されているため、新規 spec (`/<prefix>-spec` で起案するもの) と混在しない (Phase 6 で `rev-` を外す)。

feature 数が多い場合は `--domains` で絞って segmented に実行:

```
/spec-gate migrate --resume-from 3 --domains auth,users
# 後日
/spec-gate migrate --resume-from 3 --domains posts,notifications
```

## Phase 4: Constitution Draft (約 20-30 分)

`constitution-drafter` subagent が起動し、`confidence: high` の reverse spec の証拠から Principle 案を起草:

例の典型出力:

```
Principle I (NON-NEGOTIABLE): BE layering = endpoints → service → repository
Principle II (NON-NEGOTIABLE): FE separation = core / business / components
Principle III: Naming convention = file kebab-case / class PascalCase / fn snake_case
Principle IV (NON-NEGOTIABLE): Secrets via environment, not hardcoded
Principle V: Test 必須カテゴリ = endpoint, service, critical UI flow
...
```

各 Principle について AskUserQuestion で:
- 採否
- NON-NEGOTIABLE 判定の妥当性
- `existing_violations > 0` の場合は (a) 採用 + violation を `.specify/deferred-violations.md` に保存 / (b) Principle を非 NON-NEGOTIABLE に降格 / (c) 不採用 / (d) pending 等から選択
- Verification (CI / lint / test で自動検証可能か)

承認後 `.specify/memory/constitution.draft.md` の MIGRATE_SECTION fence 内に Write。Phase 6 で `constitution.md` に rename + fence marker 除去。

## Phase 5: Glossary Extraction (約 15-20 分)

`glossary-extractor` subagent が起動し、code / charter / commit から固有名詞・業務用語を抽出。同義異語や多言語混在も検出:

```
Detected synonyms:
  user / member / account (合計 65 件)  → canonical: "user" を提案
  post / article / story (合計 32 件)   → canonical: "post" を提案

Detected language mixing:
  "ユーザー" (15 件) / "User" (42 件)  → UI=ユーザー, Code=User の policy 推奨
```

各 group ごとに canonical 選択 / 規約化 を AskUserQuestion で確認。

承認後 `docs/glossary.md` に書き出し (既存があれば差分追記)。Open Questions ratio > 30% で warning。

## Phase 6: Finalize (約 20-40 分、resolves "SSoT に作業メタが残る" 問題)

migrate Phase 1-5 の出力は **working draft**。本 Phase で作業メタを `.migration-trace.md` に隔離し、本体を **product-centric な最終 SSoT** に rewrite する。

### 6.1 Finalize 対象 artifact

| Working draft | Final SSoT | Migration trace |
|---|---|---|
| `docs/discovery.md` (作業メタ込み) | `docs/discovery.md` (Build/Test/Lint + 主要 dir map のみ) | `docs/.discovery.migration-trace.md` |
| `docs/domains/<name>/charter.md` (`[observed]` 等) | 同 path (product-centric) | `docs/domains/<name>/.migration-trace.md` |
| **`specs/rev-NNN-DOM-slug/`** | **`specs/NNN-DOM-slug/`** (dir rename、`rev-` 除去) | `specs/NNN-DOM-slug/.migration-trace.md` |
| `.specify/memory/constitution.draft.md` | `.specify/memory/constitution.md` (rename) | `.specify/memory/.constitution.migration-trace.md` |
| `docs/glossary.md` (作業メタ込み) | 同 path (canonical + synonyms + polysemy のみ) | `docs/.glossary.migration-trace.md` |

### 6.2 主な rewrite 操作

各 artifact について以下を除去 (`.migration-trace.md` に移送):

- `path:line` 参照 / クラス名 / 関数名
- `[observed]` / `[aspiration]` / `[NOT-observed]` / `(推定)` inline tag
- `confidence:` / `story_type:` / `needs_human_review:` / `bf_ids:` / `sf_ids:` / `generated_by:` frontmatter
- `BOOTSTRAP_SECTION_*` / `MIGRATE_SECTION_*` fence marker (constitution)
- `## Implementation evidence` / `## Project quality score` / `## Statistics` section
- "Migrated from existing implementation" 等の **disclaimer / 逆生成言及** (markdown body のみ、HTML comment は許容)

`specs/rev-*/` は `specs/NNN-*/` に rename し、cross-reference (charter `Related Specs:`, README, CHANGELOG) を Grep + Edit で一括書換。

### 6.3 各 artifact 単位の AskUserQuestion

artifact ごとに **(a) approve / (b) revert / (c) edit & resume** を確認。

### 6.4 最終 goal

完了後、user が任意の artifact を読んだとき:

- disclaimer / 逆生成言及が一切ない
- frontmatter は SpecKit 通常 spec と同一 (`spec_id`, `domain`, `status`, `targets`, `linear` のみ)
- dir 命名は通常 spec と同一 (`specs/NNN-DOM-slug/`、`rev-` 接頭辞なし)
- body は user / product 視点 (code 由来の path:line / クラス名なし)

→ "この project は最初から SpecKit で運用されていた" と migration を知らない読み手が誤認する clean さ。

## Phase 7: Final Summary

migrate skill が完了サマリを表示:

```
✓ /spec-gate migrate 完了

  Phase 1 (Scan): docs/discovery.md
  Phase 2 (Charter): docs/domains/{auth, users, posts, notifications, admin}/charter.md (5 domains)
  Phase 3 (Spec Reverse): specs/rev-001 ... rev-024 (24 features × 7-file)  → Phase 6 で specs/001 ... 024 に rename
  Phase 4 (Constitution): .specify/memory/constitution.draft.md (Principles: 12) → Phase 6 で constitution.md
  Phase 5 (Glossary): docs/glossary.md (+48 terms)
  Phase 6 (Finalize): 全 artifact から作業メタを除去、対応 .migration-trace.md を生成
  Phase 7 (Summary): 本表示

  次のアクション:
    1. /spec-gate verify --strict で finalize 含む品質検証 (必須)
    2. 全 charter を人間レビューして status を draft → active に
    3. constitution.md を /speckit.constitution で finalize (status: active 昇格)
    4. Reverse spec の `status: completed` を順次レビュー
    5. 新規 feature 開発時は /<prefix>-spec から開始
```

## Step 7: Verify (必須推奨)

```
/spec-gate verify --strict
```

Brownfield では特に `--strict` 推奨。Phase 2.6 で finalize cleanliness (作業メタ残存 / `rev-` prefix 残存 / disclaimer 残存) を機械検出し、1 件でも残れば `fail` 判定。

期待: Phase 6 finalize が正しく走れば `ready`。何か残っていれば修正案内 `/spec-gate migrate --resume-from 6`。

## 移行後の運用

- 新規 feature: 通常通り `/<prefix>-spec → plan → tasks → design-gate → implement → code-gate → pr-gate → done`
- 既存 feature の追加変更: 該当 `specs/<NNN>-*/spec.md` (`rev-` なし、finalize 済) を読んで現状確認 → 必要なら新規 `specs/<NNN+1>-*` で改修 spec を起案
- 過去の audit を辿りたいときは同 dir の `.migration-trace.md` を参照 (通常運用では読まない)

## Tips

- 大きな repo (100+ feature) では Phase 3 を必ず `--domains` で segmented に
- Phase 2 で全 domain を一気に承認するのは危険 (cognitive load 過大)。1-2 domain ずつ 別セッションで進める
- migrate 中に新しい domain が発見されたら Constitution に追加するか、charter として別出しするか判断
- `--resume-from N` で中断・再開可能。長時間 session を避けたい場合に有効
- Phase 6 (Finalize) を skip して中身を確認したい場合は `--skip-finalize` を使用 (verify は fail するため本番には残さない)
