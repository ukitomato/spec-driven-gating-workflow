# Brownfield Migration Walkthrough

既存リポジトリに Spec-Driven Gating Workflow を導入し、`/spec-gate migrate` で Charter / Spec / Constitution / Glossary を **逆生成** する流れ。

所要時間目安: 5-10 domain の中規模プロジェクトで約 2-4 時間 (うち 60-70% はユーザ承認の対話)。

## Prerequisites

Greenfield Walkthrough の Step 1-4 (specify init → gh skill install → /spec-gate scan → /spec-gate bootstrap) を実施済。

特に Brownfield では tech stack 検出が複雑なため、`/spec-gate scan` の出力 (`docs/discovery.md`) を **必ず人間レビュー** してから `/spec-gate bootstrap` を実行する。

## Step 1: Migrate 起動

```
/spec-gate migrate
```

引数なしで Phase 1-5 を順に実行。途中中断や特定 phase だけ走らせたい場合は flag を併用:

| Flag | 効果 |
|---|---|
| `--no-reverse` | Phase 3 (Spec Reverse) を skip。governance + charter のみ |
| `--no-constitution` | Phase 4 を skip。後で `/speckit.constitution` で別途 |
| `--domains a,b` | 特定 domain のみ Phase 2-3 を実行 |
| `--resume-from 3` | Phase 3 から再開 |

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

出力 draft が AskUserQuestion で提示される。既存 `docs/discovery.md` (bootstrap 前の scan で生成済) があれば skip。

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

各 domain について Mission / Scope / User Journey / 業務ルール / KPI の **draft** が用意される。

**各 domain を 1 つずつ AskUserQuestion で承認**:

- 採用 / 統合 / 分割 / 拒否
- in scope / out of scope の境界調整
- User Journey の追記
- 業務ルールの修正
- KPI の measurable 化

承認後 `docs/domains/<name>/charter.md` を書き出し (`status: needs-human-review`)。

`docs/domains/_overview.md` に cross-domain invariants も draft される (例: "user 削除時に posts も論理削除")。

**この phase の品質が後続 phase の品質を決める** ので、対話に時間をかける。

## Phase 3: Spec Reverse (約 60-90 分)

`--no-reverse` を指定しなければ実行される。各承認済 charter 配下で feature を検出し、コード + git history + test から spec/plan/tasks を **逆生成**:

```
specs/rev-001-AUT-signup/
├── spec.md   (frontmatter: status: migrated, bf_ids: [BF-001..BF-008], sf_ids: [...])
├── plan.md   (Domain Context 自動注入済)
└── tasks.md  (全タスク [x] checked、bf_ids で実装ファイル紐付け)
```

各 feature ごとに以下を AskUserQuestion:

- "この domain 帰属で正しい?"
- "User Story の actor / benefit 推定は妥当?"
- "FR-NNN 推定で誤りはない?"
- "範囲外と判定した部分は本 feature の一部ではない?"

`rev-` prefix で物理分離されているため、新規 spec (`/<prefix>-spec` で起案するもの) と混在しない。

feature 数が多い場合は `--domains` で絞って segmented に実行:

```
/spec-gate migrate --resume-from 3 --domains auth,users
# 後日
/spec-gate migrate --resume-from 3 --domains posts,notifications
```

## Phase 4: Constitution Draft (約 20-30 分)

`constitution-drafter` subagent が起動し、Phase 1-3 の全証拠から Principle 案を起草:

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
- Verification (CI / lint / test で自動検証可能か)

承認後 `.specify/memory/constitution.draft.md` を書き出し。`/speckit.constitution` で finalize して `status: active` に昇格させる。

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

承認後 `docs/glossary.md` に書き出し (既存があれば差分追記)。

## Phase 6: Final Summary

migrate skill が完了サマリを表示:

```
✓ /spec-gate migrate 完了

  Phase 1 (Scan): docs/discovery.md
  Phase 2 (Charter): docs/domains/{auth, users, posts, notifications, admin}/charter.md (5 domains)
  Phase 3 (Spec Reverse): specs/rev-001 ... rev-024 (24 features)
  Phase 4 (Constitution): .specify/memory/constitution.draft.md (Principles: 12)
  Phase 5 (Glossary): docs/glossary.md (+48 terms)

  次のアクション:
    1. /spec-gate verify で品質検証 (必須推奨)
    2. 全 charter を人間レビューして status を active に
    3. constitution.draft.md を /speckit.constitution で finalize
    4. Reverse spec の status: migrated, needs_human_review を順次レビュー
    5. 新規 feature 開発時は /<prefix>-spec から開始
```

## Step 7: Verify (必須推奨)

```
/spec-gate verify --strict
```

Brownfield では特に `--strict` 推奨。reverse spec の `status: migrated, needs_human_review: true` 数や、charter ↔ Constitution gap を厳格に検出。

期待: 1st run では `status: warning` が普通 (charter / Constitution が draft / needs-human-review のため)。人間レビューを進めて `status: active` に上げると `ready` になる。

## 移行後の運用

- 新規 feature: 通常通り `/<prefix>-spec → plan → tasks → design-gate → implement → code-gate → pr-gate → done`
- 既存 feature の追加変更: 該当 `specs/rev-*/spec.md` を読んで現状確認 → 必要なら新規 `specs/NNN-*` で改修 spec を起案
- 移行直後は reverse spec の確信度が Medium / Low なものがあるため、PR 時に随時 spec を更新

## Tips

- 大きな repo (100+ feature) では Phase 3 を必ず `--domains` で segmented に
- Phase 2 で全 domain を一気に承認するのは危険 (cognitive load 過大)。1-2 domain ずつ 別セッションで進める
- migrate 中に新しい domain が発見されたら Constitution に追加するか、charter として別出しするか判断
- `--resume-from N` で中断・再開可能。長時間 session を避けたい場合に有効
