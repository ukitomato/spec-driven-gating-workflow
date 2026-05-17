# Greenfield Walkthrough

新規リポジトリに Spec-Driven Gating Workflow を導入し、最初の feature を 1 サイクル回すまでの流れ。

所要時間目安: 約 40-70 分 (うち 50 分は実装、残りは setup と review)。

## Prerequisites

```bash
gh --version          # 2.90.0+ (gh skill 同梱)
uv --version          # >= 0.5
specify --version     # >= 0.8 (uv tool install specify-cli)
claude --version      # Claude Code (any recent version)
```

## Step 1: SpecKit 初期化

```bash
mkdir my-new-project && cd my-new-project
git init
specify init
```

`.specify/` 配下に SpecKit の骨格が配置される。

## Step 2: spec-gate skill のインストール

```bash
gh skill install ukitomato/spec-driven-gating-workflow spec-gate \
  --agent claude-code --pin v0.1.0
```

期待出力 (抜粋):

```
Installing skill spec-gate from ukitomato/spec-driven-gating-workflow@v0.1.0...
Resolved to: ukitomato/spec-driven-gating-workflow@v0.1.0 (tree SHA: abc123...)
Installing to: .claude/skills/spec-gate/
✓ Installed spec-gate@v0.1.0
```

確認:

```bash
ls .claude/skills/spec-gate/      # SKILL.md, references/, scripts/
gh skill list                      # spec-gate が pin 付きで表示される
```

## Step 3: Scan — tech stack 検出

Claude Code を起動:

```
/spec-gate scan
```

実行内容:
1. `discovery-scanner` subagent が `.claude/agents/` に配置される
2. subagent が clean-context で起動
3. `package.json` / `pyproject.toml` / `pubspec.yaml` 等を解析
4. Project Profile draft が AskUserQuestion で提示される
5. ユーザが採用 / 編集 → `docs/discovery.md` が `status: needs-human-review` で書き出される

確認:

```bash
head -30 docs/discovery.md
```

## Step 4: Bootstrap — workflow wrapper 配置

```
/spec-gate bootstrap
```

実行内容:

**Phase 1: Prefix 確定**
AskUserQuestion で 4 候補から選択:
- `spec-gate` (default)
- `my-new-project` (package name 由来)
- `mnp` (短縮形)
- 自由入力

例として `myproj` を選択。

**Phase 2: Generic reviewer 配置**
5 個の SubAgent が `.claude/agents/` に Write:
- `reviewer-base.md`
- `security-reviewer.md`
- `architecture-reviewer.md`
- `po-reviewer.md`
- `convention-reviewer.md`

**Phase 3: Reviewer 構成提案** ★
tech stack に応じた構成を提示:

```
プロジェクトの tech stack を検出しました:
  - Frontend: Vue 3 + Pinia
  - Backend: FastAPI + SQLAlchemy
  - Database: PostgreSQL with Alembic migrations

レビュアー構成を選択してください:

  最少 (minimum)  : 4 generic reviewer のみ
  適切 (recommended) ← おすすめ: + database-reviewer + api-performance-reviewer + a11y-reviewer
  最大 (maximum)  : + 全 5 optional
  カスタム (custom) : 各 optional を個別に on/off
```

「適切」を選ぶと 3 optional reviewer が追加配置される。

**Phase 4: Wrapper 配置**
9 個の daily wrapper が `.claude/skills/myproj-*/SKILL.md` として Write:
- myproj-spec, myproj-plan, myproj-tasks, myproj-design-gate, myproj-implement, myproj-code-gate, myproj-pr-gate, myproj-done, myproj-add-reviewer

**Phase 5-7: 補助ファイル / Constitution scaffold / 検証**

完了メッセージ:

```
✓ /spec-gate bootstrap 完了
  Prefix: myproj
  Wrappers (9): /myproj-{spec,plan,tasks,design-gate,implement,code-gate,pr-gate,done,add-reviewer}
  Generic reviewer: 5 (+base)
  Optional reviewer adopted: database-reviewer, api-performance-reviewer, a11y-reviewer
  Constitution scaffold: .specify/memory/constitution.draft.md
```

## Step 5: Verify — 開発 Ready チェック

```
/spec-gate verify
```

5 phase (構造 / 整合 / 過不足 / dev-ready / レポート) を実行。`docs/verify-report.md` が出力される。

期待: `overall_status: ready` (Greenfield なら warning でも可、fail なら修正)。

## Step 6: Constitution finalize (任意)

```
/speckit.constitution
```

`.specify/memory/constitution.draft.md` をレビューし、`status: active` に昇格。

## Step 7: Domain Charter 作成

最低 1 domain 必要:

```bash
mkdir -p docs/domains/auth
cp .specify/templates/spec-gate/domain-charter-template.md docs/domains/auth/charter.md
# editor で Mission / Scope / User Journey / 業務ルール / KPI を埋める
```

## Step 8: 最初の feature を起案

```
/myproj-spec "[auth] ユーザのメール+パスワード新規登録"
```

Skill が実行:
1. domain (`auth`) の charter 存在を確認 ✓
2. `--spec-id-format seq` で `specs/001-auth-signup/spec.md` を `/speckit.specify` で起草
3. frontmatter に `spec_id` / `domain` / `targets` / `status: drafting` を注入
4. `/speckit.clarify` を auto chain (LLM が assumption で埋めずユーザに質問)

ユーザは clarify の質問に対し具体的に回答 (skip も可)。

## Step 9: Plan → Tasks

```
/myproj-plan
```

→ `specs/001-auth-signup/plan.md` 生成。"Domain Context" section に charter / ADR / glossary が自動注入される。status: `drafting → planning`。

```
/myproj-tasks
```

→ `tasks.md` 生成。`targets: both` の場合は Backend / Frontend / Shared に分割。status: `planning → tasking`。

## Step 10: Design Gate

```
/myproj-design-gate
```

3 並列 reviewer (`/speckit.analyze` + `po-reviewer` + `architecture-reviewer`) が clean context で起動。`design-gate.md` に集約。

- Critical = 0 → status: `tasking → implementing`、次へ
- Critical > 0 → spec / plan / tasks を修正後に再実行

## Step 11: Implement → Code Gate

```
/myproj-implement
```

`/speckit.implement` 内部委譲で実装が走り、tasks.md の checkbox が `[x]` になる。完了後 `/myproj-code-gate` が auto-chain。

code-gate は lint / test / convention-reviewer / api-performance-reviewer (Step 4 で追加した) を並列起動し、MUST_FIX があれば auto-fix loop (max 3 iter)。

PASS なら status: `implementing → reviewing`。

## Step 12: PR Gate

```
/myproj-pr-gate
```

5+3 並列 adversarial reviewer が `git diff develop...HEAD` 全体を多角的にレビュー。Critical = 0 で `/myproj-done` を許可。

修正後の Round 2, 3 は同コマンドで自動的に round 番号が増える。

## Step 13: Done

```
/myproj-done
```

6-stage gate を順に通り、format / commit / push / PR create を実行。status: `reviewing → completed`。

## 1 サイクル完了時の成果物

```
specs/001-auth-signup/
├── spec.md            (frontmatter: status: completed)
├── plan.md
├── tasks.md           (全タスク [x])
├── design-gate.md     (Verdict: PASS)
├── code-gate.md       (Verdict: PASS)
├── pr-gate.md         (Verdict: PASS Round N)
└── touched-files.txt
```

GitHub / GitLab に PR が作成され、Linear/Issue 連携指定時はコメント投稿済。

## 後続: 2 つ目以降の feature

```
/myproj-spec "[posts] Quote post 機能"
```

domain `posts` の charter が必要なので、まず `docs/domains/posts/charter.md` を作成。以降は同じフロー。
