# /spec-gate verify — subcommand body

> Loaded by `skills/spec-gate/SKILL.md` (dispatcher) when the first argument is `verify`.

開発 ready 検証 + 整合性チェック。`/spec-gate bootstrap` 完了後 / `/spec-gate migrate` 完了後 / 任意のタイミングで実行可能。問題の早期発見と「品質が低い状態で開発を始めない」ためのゲート。`docs/verify-report.md` を出力する。

## Inputs

- `$ARGUMENTS` (subcommand 抜き残り):
  - `--phase <N>` (1-5): 特定 phase だけ実行
  - `--strict`: warning も `fail` 扱い
  - `--prefix <name>`: 検証対象 prefix を明示 (省略時は `.claude/skills/<prefix>-spec/` の存在から自動検出)

## Phase 0: Preconditions

1. `.specify/` 存在確認
2. prefix を検出:
   - `--prefix` flag があれば使用
   - 無ければ `.claude/skills/<prefix>-spec/` を `ls` して prefix を抽出
   - 0 件 → halt with "/spec-gate bootstrap を先に実行してください"
   - 複数候補 → AskUserQuestion で選択
3. `--phase` flag に応じて phase 1-5 のうち実行対象を確定

## Phase 1: 構造検証 (Existence Check)

「必要な file / dir が揃っているか」の純粋なチェック。

```bash
# 必須 file / dir リスト (チェック対象)
REQUIRED:
  .specify/memory/constitution.md (or constitution.draft.md)
  .specify/templates/spec-gate/  (bootstrap が配置済)
  .specify/scripts/spec-resolve.sh  (実行可能)
  .specify/scripts/status-transition.sh  (実行可能)
  docs/discovery.md
  docs/domains/  (1+ subdirectory)
  docs/glossary.md
  .claude/skills/<prefix>-{spec,plan,tasks,design-gate,implement,code-gate,pr-gate,done,add-reviewer}/SKILL.md  (9個)
  .claude/agents/{reviewer-base,security-reviewer,architecture-reviewer,po-reviewer,convention-reviewer}.md  (5個)
```

各項目について:
- 存在しなければ `fail` (Phase 1 fail = report 全体 fail)
- 存在するが `status: needs-human-review` のまま → `warning`
- `status: active` → `pass`

verification report の Phase 1 section に結果を記録 (table 形式)。

## Phase 2: 整合性検証 (Cross-Reference Consistency)

frontmatter / 参照関係の妥当性チェック。

### 2.1 spec frontmatter validity

`specs/*/spec.md` の全件:
- `spec_id` が valid 形式 (`^[0-9]{3}-[a-z-]+$` or `^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{4}-[A-Z]+-[a-z-]+$` or `^rev-[0-9]{3}-[A-Z]+-[a-z-]+$`)
- `domain` が `docs/domains/<value>/charter.md` に対応する実 domain
- `status` が valid な enum 値 (drafting / planning / tasking / implementing / reviewing / completed / migrated)
- `targets` が valid (frontend / backend / both / null)
- (reverse spec の場合) `bf_ids` / `sf_ids` が空配列でない

### 2.2 bf_ids / sf_ids の code references

reverse spec (`specs/rev-*/`) の `bf_ids` / `sf_ids` で参照されているコードが実存:

```bash
# 例: bf_ids: ["BF-001"], spec body で "lib/auth/login.py:42" を引用しているなら
grep -rn 'BF-001' <referenced files>
```

存在しなければ `warning` (コードがリファクタされた可能性)、5+ 件で `fail`。

### 2.3 reverse spec ↔ charter の対応

全 `specs/rev-*/` に対し:
- `frontmatter.domain` の charter `docs/domains/<domain>/charter.md` が存在
- 不在なら `fail` (charter が削除されたか domain が未承認)

### 2.4 reviewers.yml ↔ `.claude/agents/` の一致

`.specify/spec-gate/reviewers.yml` の entry と `.claude/agents/*.md` の実在ファイルが一致:
- registry にあるが agent file なし → `fail` (broken registry)
- agent file はあるが registry に未登録 → `warning` (手動配置の可能性)

## Phase 3: 過不足検証 (Gap Analysis)

「あるべきもの」と「現状」の差分を semantic に判定 (LLM 判断含む)。

### 3.1 Constitution Principle ↔ Reviewer Owner Matrix の覆い

`.specify/memory/constitution.md` の各 Principle を Read し、その Principle が要求する観点が現状の reviewer 構成で十分カバーされているかを LLM が判定:

例:
- Principle "All endpoints follow OpenAPI" あり、かつ project に `openapi.yaml` ある → `openapi-contract-reviewer` 未採用なら `warning` + 提案 ("/spec-gate-add-reviewer openapi-contract-reviewer --from-template" を案内)
- Principle "Database migrations must be reversible" あり → `database-reviewer` 未採用なら `warning`
- Principle "Accessibility: WCAG 2.1 AA" あり → `a11y-reviewer` 未採用なら `warning`

検出された gap は `verify-report.md` の "Reviewer Coverage Gaps" section に列挙。

### 3.2 Charter scope ↔ Constitution Principle

各 charter の Mission / Scope を Read し、Constitution Principle で関連する Principle が存在するかを LLM が判定:
- e.g., charter で "user authentication" が中心 mission なのに、Constitution に auth 関連 Principle なし → `warning` + Constitution amendment を提案

### 3.3 Glossary 用語の使用状況

`docs/glossary.md` の各用語に対し:
- 0 件のコード参照 (`grep -rc "<term>" lib/ src/`) → `warning` (未使用、削除候補)
- glossary 未登録だがコード頻出 (`grep -rc` で多数ヒット、generic words を除外) → `warning` (glossary 追加候補)

## Phase 4: 開発 Ready チェック (Dry-Run)

`docs/discovery.md` 記載の build / test / lint コマンドを Bash で dry-run 実行:

### 4.1 Build / Test / Lint コマンドの存在確認

```bash
# 例
which pnpm && pnpm --version
which pytest && pytest --version
which flutter && flutter --version
```

`docs/discovery.md` の "Build / Test / Lint" section から取得したコマンドが存在しなければ `warning`。

### 4.2 Lint dry-run

実際に lint コマンドを実行 (read-only mode):
```bash
pnpm lint --max-warnings 0 --silent 2>&1 | head -20
ruff check . --statistics 2>&1 | head -10
flutter analyze --no-fatal-warnings 2>&1 | head -20
```

exit code 非ゼロ → `warning` (既存コードの lint 違反、新規開発の参考情報として記録)。

### 4.3 Entry point 確認

主要 entry point の存在 (project 種別に応じて):
- `package.json` の `scripts.dev` / `scripts.start` 存在
- Python: `pyproject.toml` の `[project.scripts]` または `main.py`
- Flutter: `lib/main.dart`
- Go: `main.go` または `cmd/<name>/main.go`

不在なら `warning`。

### 4.4 `.specify/scripts/` の実行可能性

```bash
[ -x .specify/scripts/spec-resolve.sh ] && echo "spec-resolve.sh OK" || echo "FAIL: not executable"
[ -x .specify/scripts/status-transition.sh ] && echo "status-transition.sh OK" || echo "FAIL: not executable"
```

非実行可能 → `fail` (`chmod +x` で修正可能なので修正案内も出す)。

### 4.5 Environment / secrets チェック

- `.env.example` の存在
- 環境変数 `OPENAI_API_KEY` / `ANTHROPIC_API_KEY` 等の hardcode 検出 (`grep -rE 'sk-[a-zA-Z0-9]{32,}'`)
- 検出されれば `fail` (secret leak)

## Phase 5: レポート出力

`docs/verify-report.md` に Markdown で書き出し:

```markdown
---
generated_by: /spec-gate verify
generated_at: <ISO 8601>
prefix: <prefix>
strict_mode: <true|false>
overall_status: <ready | warning | fail>
---

# Verify Report: <project-name>

## Summary

| Phase | Verdict | Count of issues |
|---|---|---|
| 1. Structure | pass / warning / fail | <n> |
| 2. Consistency | pass / warning / fail | <n> |
| 3. Gap Analysis | pass / warning / fail | <n> |
| 4. Dev Ready | pass / warning / fail | <n> |

**Overall status**: <ready | warning | fail>

## Phase 1: Structure

(table of required files/dirs, status, path)

## Phase 2: Consistency

(per-issue details with severity)

## Phase 3: Gap Analysis

### Reviewer Coverage Gaps
- ...

### Charter ↔ Constitution Gaps
- ...

### Glossary Usage Gaps
- ...

## Phase 4: Dev Ready

- Build/Test/Lint commands: <status>
- Lint dry-run: <output summary>
- Entry points: <status>
- Helper scripts: <status>
- Secrets check: <status>

## Recommended actions

(prioritized list of fixes, with copy-paste commands when possible)
- [ ] Run `/<prefix>-add-reviewer openapi-contract-reviewer --from-template` to fill OpenAPI gap
- [ ] Update `docs/domains/auth/charter.md` status from `needs-human-review` to `active`
- [ ] `chmod +x .specify/scripts/spec-resolve.sh`
...
```

## Overall status の決定

- **ready**: 全 phase が `pass` (warning も無し)
- **warning**: 1+ warning、ただし fail なし。`--strict` モードではこれも fail 扱い
- **fail**: Phase 1 / 2 で `fail` 検出 (Phase 3 / 4 の fail は warning に降格)

## Idempotency

- 既存 `docs/verify-report.md` は毎回上書き (履歴は git で追える前提)
- `--phase <N>` で部分実行した場合、その phase だけの report を生成 (他 phase は前回値を引継ぎ)

## Failure modes

- prefix 検出不能 → AskUserQuestion で明示指定要求
- `docs/discovery.md` 不在 → Phase 4 を skip して報告
- Lint コマンド未インストール → Phase 4.1 warning、Phase 4.2 skip
- subagent 起動不要 (本 subcommand は subagent を使わない、本体 LLM が直接判定)

## Acceptance criteria

1. `docs/verify-report.md` が存在し、5 phase の verdict が記録
2. `overall_status` が ready / warning / fail のいずれかで明記
3. Recommended actions section に具体的な修正コマンド or 案内が記載
4. `--strict` モードで warning も fail にエスカレートされる
5. `--phase 3` のような部分実行が動作する
