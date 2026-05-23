# Adoption Guide

新規プロジェクト (Greenfield) と既存プロジェクト (Brownfield) への導入手順。

## どちらに該当するか判定

| 状態 | 該当 |
|---|---|
| 空ディレクトリ、または `git init` 直後で commit 数 0 | **Greenfield** |
| 既存コードあり、test/CI 整備済、ドキュメント皆無 or 散在 | **Brownfield** |
| 既存コードあり、Constitution / Charter / Glossary が既に整備済 | **Greenfield 扱い** (新規 feature のみ Spec-Driven Gating Workflow に乗せる) |

## Prerequisites

```bash
# GitHub CLI v2.90.0+ (gh skill 同梱)
gh --version    # 2.90.0 以上

# SpecKit
curl -LsSf https://astral.sh/uv/install.sh | sh
uv tool install specify-cli
specify --version

# Claude Code または Cursor (1 つ以上)
```

## Greenfield Adoption

### 1. SpecKit 初期化

```bash
mkdir my-new-project && cd my-new-project
git init
specify init
```

### 2. spec-gate skill のインストール

```bash
# Claude Code 利用時
gh skill install ukitomato/spec-driven-gating-workflow spec-gate \
  --agent claude-code --pin v0.1.0

# Cursor / Copilot / Codex 等を併用する場合 (`.agents/skills/` 共有 group)
gh skill install ukitomato/spec-driven-gating-workflow spec-gate \
  --agent cursor --pin v0.1.0
```

### 3. Scan: tech stack 検出

Claude Code (または Cursor) を起動して:

```
/spec-gate scan
```

実行内容:
1. `discovery-scanner` subagent が起動 (clean-context)
2. `package.json` / `pyproject.toml` / `pubspec.yaml` / `Cargo.toml` / `go.mod` / `pom.xml` 等を解析
3. tech stack / build/test/lint コマンド / CI 設定を識別
4. Project Profile draft が出力される
5. AskUserQuestion でユーザが確認 / 編集
6. `docs/discovery.md` が `status: needs-human-review` で書き出される

### 4. Bootstrap: workflow wrapper 配置

```
/spec-gate bootstrap
```

実行内容:
1. **Prefix 確定**: AskUserQuestion で `spec-gate` (default) or project 名 / 短縮形 / 自由入力から選択
2. **Generic reviewer 配置**: `reviewer-base` + `security` / `architecture` / `po` / `convention` の 5 個を `.claude/agents/` に Write
3. **Reviewer 構成提案** (★): tech stack に応じて optional reviewer (database / a11y / api-performance / openapi-contract / ux) を 4 構成 (最少 / 適切 / 最大 / カスタム) で提案。ユーザ選択
4. **Wrapper 配置**: 9 個の daily workflow wrapper を `.claude/skills/<prefix>-*/SKILL.md` として Write (`{{prefix}}` を確定値で置換)
5. **補助ファイル配置**: Constitution / Charter / Glossary 雛形、AGENTS.md / CLAUDE.md merge、`spec-resolve.sh` / `status-transition.sh` を `.specify/scripts/`
6. **Constitution scaffold**: tech stack 別 Principle 案を `.specify/memory/constitution.draft.md` に書き出し

### 5. Constitution finalize (任意)

```
/speckit.constitution
```

draft をレビューし、`status: active` に昇格させる。NON-NEGOTIABLE Principle は厳格に判定。

### 6. Domain Charter 作成

Greenfield なので migrate は使わず、手動で `docs/domains/<name>/charter.md` を作成:

```bash
mkdir -p docs/domains/auth
cp .specify/templates/spec-gate/domain-charter-template.md docs/domains/auth/charter.md
# editor で Mission / Scope / User Journey / 業務ルール / KPI を埋める
```

最低 1 domain 以上が必要 (`/<prefix>-spec` で起案時に charter 存在チェックが走る)。

### 7. Glossary 初期化 (任意)

```bash
cp .specify/templates/spec-gate/glossary-template.md docs/glossary.md
```

最初は空でも可。feature 開発を進めるなかで増えていく。

### 8. Verify: 開発 Ready チェック

```
/spec-gate verify
```

実行内容:
1. **Phase 1 構造検証**: 必要 file / dir の存在確認 (9 wrapper、5 generic subagent、Constitution、charter、glossary)
2. **Phase 2 整合性検証**: frontmatter validity、reverse spec ↔ charter 対応、reviewers.yml ↔ `.claude/agents/` 一致
3. **Phase 3 過不足検証**: Constitution Principle ↔ Reviewer Owner Matrix の覆い、Charter scope ↔ Constitution Principle、Glossary 用語使用状況
4. **Phase 4 開発 Ready**: build/test/lint コマンドの dry-run、entry point 存在、scripts 実行可能性、secret 検出
5. **Phase 5 レポート出力**: `docs/verify-report.md` (status: ready / warning / fail)

ready になるまで指摘事項を修正。

### 9. 最初の feature を起案

```
/<prefix>-spec "[auth] ユーザのメール+パスワード新規登録"
```

以降は [tutorials/greenfield-walkthrough.md](../tutorials/greenfield-walkthrough.md) の通り。

## Brownfield Adoption

### 1-4 は Greenfield と同じ (specify init → gh skill install → /spec-gate scan → /spec-gate bootstrap)

### 5. Migrate: Charter Reverse + Spec Reverse + Constitution + Glossary

```
/spec-gate migrate
```

5-phase orchestrator が起動:

1. **Phase 1 Surface Scan** (5 分): discovery-scanner、既存 `docs/discovery.md` あれば skip
2. **Phase 2 Domain Charter Reverse** (30-60 分): charter-drafter、各 domain ごとに AskUserQuestion 承認 → `docs/domains/<name>/charter.md`
3. **Phase 3 Spec Reverse** (60-90 分): spec-reverser、各 feature ごとに承認 → `specs/rev-<NNN>-<DOM>-<slug>/{spec,plan,tasks}.md` (status: migrated, bf_ids/sf_ids)
4. **Phase 4 Constitution Draft** (20-30 分): constitution-drafter、既存 draft があれば merge
5. **Phase 5 Glossary Extraction** (15-20 分): glossary-extractor、既存 glossary と差分追記

詳細は [tutorials/brownfield-migration.md](../tutorials/brownfield-migration.md)。

### 6. 分割実行 (大規模 repo の場合)

100+ feature や 10+ domain のリポジトリでは:

```bash
# Day 1: governance のみ
/spec-gate migrate --no-reverse --no-constitution

# Day 2-N: domain ごとに spec reverse
/spec-gate migrate --resume-from 3 --domains auth,identity
/spec-gate migrate --resume-from 3 --domains posts,messaging

# 最後: Constitution + Glossary
/spec-gate migrate --resume-from 4
```

### 7. Verify

```
/spec-gate verify --strict
```

Brownfield では特に `--strict` 推奨。reverse spec の `status: migrated, needs_human_review: true` 数や、charter ↔ Constitution gap を厳格に検出。

## Multi-editor 運用 (Claude Code + Cursor 等)

```bash
# Claude Code 用
gh skill install ukitomato/spec-driven-gating-workflow spec-gate --agent claude-code --pin v0.1.0

# Cursor / Copilot / Codex 等用 (1 回で 9 host 共有)
gh skill install ukitomato/spec-driven-gating-workflow spec-gate --agent cursor --pin v0.1.0
```

両エディタで同じ `/spec-gate <subcommand>` 動作。Bootstrap が生成する daily wrapper も両エディタで利用可能。

## Team rollout

### Phase 1: Pilot

1 feature を 1 開発者が一通り回す。Acceptance criteria は各 SKILL.md の末尾 section で実体験検証。

### Phase 2: Team adoption

- AGENTS.md / CLAUDE.md に team-wide rule として記録 (bootstrap が merge 済)
- onboarding doc に Spec-Driven Gating Workflow セクションを追加
- PR review で gate verdict を required check 化

### Phase 3: CI integration (optional)

- `code-gate` の lint / test 部分を CI でも実行
- `design-gate.md` / `pr-gate.md` の存在を required artifact 化
- merge protection rule で gate verdict PASS を要求

## トラブルシューティング

### "/<prefix>-* SKILL が見えない"

- `gh skill install` が完了しているか (`gh skill list`)
- `/spec-gate bootstrap` を実行済か (skill list で `<prefix>-spec` 等が出るか)
- Claude Code を再起動 (live change detection が effective)

### "design-gate が常に Critical を出す"

- spec.md の `[NEEDS CLARIFICATION]` が残っていないか
- charter / Constitution が `status: active` か (draft のままだと参照が弱い)
- `/spec-gate verify --strict` で構造的問題を先に解消

### "code-gate の auto-fix loop が cascade exhaustion で halt"

- 修正のたびに新規 violation が増える → 設計レベルの問題
- `/<prefix>-design-gate` に戻って spec / plan を見直す

### "pr-gate Round 4 で convergence failure"

- 修正と新規発見が同 round で拮抗 (隣接 2 round で resolved < new、v0.2.0 数学定義)
- v0.2.0 で `--defer-remaining` は撤廃済 (pure hard gate)
- 対応: ADR を新規起票して "現状を accept する" 経路 → Constitution Principle / spec 範囲調整 → 再 pr-gate (Round N+1)

### "/spec-gate コマンドが見つからない / failed to load"

- `gh skill list` で `spec-gate` が install されているか確認
- `gh --version` で v2.90.0+ か確認
- `gh skill update ukitomato/spec-driven-gating-workflow` で最新を取得
