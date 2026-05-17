# Architecture

Spec-Driven Gating Workflow の **設計判断** と **配置の根拠**。

## 設計原則

### 原則 1: 1 個の gh skill + subcommand dispatch (agentskills.io progressive disclosure)

`spec-gate` は **agentskills.io の progressive disclosure pattern** に厳密に従う:

- **Tier 1 — Discovery (~100 tokens)**: skill のカタログには `name: spec-gate` と `description` のみ。`gh skill install` 後、host (Claude Code / Cursor 等) は startup 時に全 skill の name + description を読み込む
- **Tier 2 — Activation (~3-5K tokens)**: ユーザが `/spec-gate <subcommand>` を invoke すると、host は `SKILL.md` body をフルロード。dispatcher は `$ARGUMENTS` を見て該当する `references/commands/<subcommand>.md` を Read する指示を出す
- **Tier 3 — Execution (on-demand)**: subcommand body を Read 後、必要な reference (subagent body, wrapper template, helper script) を Read tool で個別ロード

これにより:
- 単一 install で 4 機能 (scan / bootstrap / migrate / verify) すべて利用可能
- 起動時のメタデータコストは 1 skill 分のみ (~100 tokens)
- 各 subcommand は必要なときだけロード

### 原則 2: 配布は gh skill v2.90.0+ に一本化

`gh skill` は GitHub CLI v2.90.0 (2026-04-16) で導入された SKILL 管理 subcommand:

- **Provenance**: install 時に source repo / ref / tree SHA が `SKILL.md` frontmatter に自動注入
- **Pinning**: `--pin v1.2.0` または commit SHA でロック
- **Content-based update**: `gh skill update` は tree SHA で実コンテンツ変更を検出 (バージョン番号でなく実体)
- **Multi-host support**: Copilot / Claude Code / Cursor / Codex / Gemini CLI / Antigravity / Amp / Goose / Junie / OpenCode / Windsurf 等 30+ host
- **Shared directory**: 9 host (Cursor / Copilot / Codex / Gemini CLI / Antigravity / Amp / Cline / OpenCode / Warp) が `.agents/skills/` を共有、`--agent <any>` で 1 度 install すれば共通

Claude Code は `.claude/skills/` を独自に持つため、Claude Code + 他 host の併用は `--agent claude-code` と `--agent <other>` の 2 回 install で対応。

### 原則 3: META subcommand (`/spec-gate *`) と Daily wrapper (`/<prefix>-*`) の役割分担

| 階層 | 命名 | 用途 |
|---|---|---|
| **META** (4) | `/spec-gate <subcommand>` 固定 | setup / 検証などの project 全体操作 (一度きり or 稀) |
| **Daily** (9) | `/<prefix>-<name>` ユーザ指定 | feature 単位で繰り返し実行する workflow step |

META subcommand は固定名 `spec-gate` をそのまま使う。Daily wrapper はユーザがチーム / project 固有の慣習に合わせて prefix を選べる (例: `mycompany-spec`, `mycompany-design-gate`)。

### 原則 4: SubAgent は project-local 配置

`gh skill install` は SKILL.md とその bundled files を配置するが、`.claude/agents/` (SubAgent) は管理対象外。SubAgent は各 subcommand body が runtime で `${CLAUDE_SKILL_DIR}/references/subagents/<name>.md` を Read → `.claude/agents/<name>.md` に Write することで配置する:

- bootstrap が 5 個 (reviewer-base + 4 generic reviewer) を配置
- migrate が 5 個 (brownfield specialist) を追加配置
- 採用された optional reviewer (bootstrap Phase 3 の構成提案結果) が追加配置

SubAgent は **read-only** (`tools: Read, Grep, Glob`)、`convention-reviewer` のみ `Bash` 許可 (lint コマンド実行)、brownfield specialist は `Bash` 許可 (git log scan)。clean-context isolation を守る:

- 呼び出し元 skill / wrapper の会話履歴を渡さない
- 「事情を知らない初見レビュワー」として機能、盲点を出す
- 最低 3 件の Critical 強制 (同調バイアス打消し)

### 原則 5: Status lifecycle による hard gating

```
drafting → planning → tasking ─[design-gate]→ implementing ─[code-gate]→ reviewing ─[pr-gate]→ completed
```

- 各 gate (design / code / pr) の verdict が PASS にならない限り次 status に進まない
- gate 通過は `.specify/scripts/status-transition.sh` が現状値の正当性を validate してから書き換え
- 例外ルートなし (skip / override は明示的な flag を要する)

これが「Spec-Driven **Gating** Workflow」の核心。

### 原則 6: SSoT (Single Source of Truth)

3 つの SSoT:

| What | Where |
|---|---|
| Constitution Principle | `.specify/memory/constitution.md` |
| Domain Charter | `docs/domains/<name>/charter.md` |
| Ubiquitous Language | `docs/glossary.md` |

reviewer subagent は判定のためにこれら 3 つを Tier-0 必読として Read する。drift 検出はここを基準にする。

## Components

### Layer 1: gh skill 配布 (`ukitomato/spec-driven-gating-workflow`)

```
skills/spec-gate/
├── SKILL.md                          # dispatcher (~100 lines)
├── references/
│   ├── commands/                     # 4 subcommand body (scan / bootstrap / migrate / verify)
│   ├── subagents/                    # 10 SubAgent body
│   ├── wrappers/                     # 9 daily workflow wrapper template ({{prefix}} marker)
│   ├── reviewers-optional/           # 5 optional reviewer body
│   ├── docs-templates/               # Constitution / Charter / Glossary 雛形
│   ├── memory/                       # AGENTS.md / CLAUDE.md merge template
│   └── lang/                         # ja.json / en.json
└── scripts/                          # helper scripts (spec-resolve, status-transition)
```

### Layer 2: META subcommands (4)

| Subcommand | 役割 | Status 遷移 |
|---|---|---|
| `/spec-gate scan` | tech stack 検出 → `docs/discovery.md` | (none) |
| `/spec-gate bootstrap` | 9 daily wrapper + 4 generic reviewer + 提案 optional reviewer + Constitution scaffold | (none) |
| `/spec-gate migrate` | Brownfield 5-phase: Charter Reverse / Spec Reverse / Constitution / Glossary | (none) |
| `/spec-gate verify` | 品質ゲート: 構造 / 整合 / 過不足 / dev-ready → `docs/verify-report.md` | (none) |

### Layer 3: Daily wrappers (9、bootstrap が生成)

| 種別 | Wrapper | Status 遷移 |
|---|---|---|
| Producer | `/<prefix>-spec` | → drafting |
| Producer | `/<prefix>-plan` | drafting → planning |
| Producer | `/<prefix>-tasks` | planning → tasking |
| **Gate** | `/<prefix>-design-gate` | tasking → implementing |
| Producer | `/<prefix>-implement` | → implementing |
| **Gate** | `/<prefix>-code-gate` | implementing → reviewing |
| **Gate** | `/<prefix>-pr-gate` | (no transition、Critical=0 で done 許可) |
| Producer | `/<prefix>-done` | reviewing → completed |
| Customization | `/<prefix>-add-reviewer` | (none、reviewer 増減) |

### Layer 4: SubAgents (10)

| 種別 | Agent | 配置 subcommand |
|---|---|---|
| Base | `reviewer-base` | bootstrap |
| Generic reviewer | `security-reviewer` | bootstrap |
| Generic reviewer | `architecture-reviewer` | bootstrap |
| Generic reviewer | `po-reviewer` | bootstrap |
| Generic reviewer | `convention-reviewer` | bootstrap |
| Brownfield specialist | `discovery-scanner` | scan / migrate |
| Brownfield specialist | `charter-drafter` | migrate |
| Brownfield specialist | `spec-reverser` | migrate |
| Brownfield specialist | `constitution-drafter` | migrate |
| Brownfield specialist | `glossary-extractor` | migrate |

加えて optional 5 reviewer (`database`, `a11y`, `api-performance`, `openapi-contract`, `ux`) が `references/reviewers-optional/` に同梱、bootstrap Phase 3 (reviewer 構成提案) で採用されたものが配置される。

## Workflow flow

```
                ┌── /spec-gate scan ──→ docs/discovery.md
                ▼
                ├── /spec-gate bootstrap ──→ 9 wrapper + 5 subagent + Constitution scaffold
                │                              ★ Phase 3 で optional reviewer を AskUserQuestion 提案
                ▼
                ├── (Brownfield) /spec-gate migrate ──→ Charter / Spec Reverse / Constitution / Glossary
                ▼
                ├── /spec-gate verify ──→ docs/verify-report.md (status: ready/warning/fail)
                ▼
                ├── /<prefix>-spec ──→ specs/<dir>/spec.md         (drafting)
                ├── /<prefix>-plan ──→ plan.md                      (planning)
                ├── /<prefix>-tasks ──→ tasks.md                    (tasking)
                ┃     ┌──────────────────────────────────────────┐
                ┃     │ design-gate: spec + plan + tasks bundle  │
                ┃     │ - speckit.analyze (machine consistency)  │
                ┃     │ - po-reviewer (User Story value)         │
                ┃     │ - architecture-reviewer (Constitution)   │
                ┃     │   3 並列 clean-context                   │
                ┃     └──────────────────────────────────────────┘
                ▼              Critical=0
                ├── /<prefix>-implement ──→ code (implementing) + auto-chain code-gate
                ┃     ┌──────────────────────────────────────────┐
                ┃     │ code-gate: working tree diff             │
                ┃     │ - lint / test / convention-reviewer +    │
                ┃     │   tech-stack reviewer (3-5 並列)         │
                ┃     │ MUST_FIX → auto-fix loop (max 3 iter)    │
                ┃     └──────────────────────────────────────────┘
                ▼              PASS
                ├── /<prefix>-pr-gate ──→ pr-gate.md.round<N>       (reviewing)
                ┃     ┌──────────────────────────────────────────┐
                ┃     │ pr-gate: git diff base...HEAD            │
                ┃     │ - security / architecture / perf /       │
                ┃     │   adr-drift + convention                 │
                ┃     │   (feature scope, 5 並列)                │
                ┃     │ - + system scope reviewers (3 並列)      │
                ┃     │ Multi-round + convergence gate (>= R4)   │
                ┃     └──────────────────────────────────────────┘
                ▼              Critical=0
                └── /<prefix>-done ──→ format + commit + push + PR  (completed)
```

## Dependencies

- [GitHub CLI v2.90.0+](https://cli.github.com/) — `gh skill` 同梱
- [SpecKit](https://github.com/github/spec-kit) — `/speckit.specify`, `plan`, `tasks`, `implement`, `analyze`, `clarify`, `constitution` を chain
- `uv` — SpecKit 配布で必須
- Claude Code / Cursor / Copilot / Codex / Gemini CLI 等 — SKILL.md / SubAgent を解釈する host

## Customization points

| What | How |
|---|---|
| Daily wrapper prefix 変更 | `/spec-gate bootstrap --prefix <new>` (再実行で confirm) |
| optional reviewer 追加 | `/<prefix>-add-reviewer <name>` または `/spec-gate bootstrap` 再実行 |
| 多言語切替 | bootstrap `--lang en` / `--lang ja` |
| Reviewer body 編集 | `.claude/agents/<name>.md` を直接編集 |
| SubAgent / wrapper の追加 | カスタム subagent 作成 + reviewers.yml registry 編集 |
| Status lifecycle 拡張 | Phase 2+ (`add-wrapper` は post-MVP) |

## Non-goals

- agentskills.io catalog への公開 (Phase 2+ で対応)
- `add-wrapper` (新 workflow phase / status 追加) — post-MVP の Phase 2+ で検討
- GitHub Copilot Chat 以外のホスト固有 frontmatter 拡張 (agentskills.io 標準で十分)
- Retroactive ADR generation (Constitution と Charter は逆生成するが ADR の遡及作成は対象外)
- Python / Node.js CLI の維持 (gh skill が肩代わり)
