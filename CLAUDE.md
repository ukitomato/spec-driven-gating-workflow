# Repository Development Notes

このリポジトリは **Spec-Driven Gating Workflow の配布キットそのもの** を開発する場所です。`README.md` / `docs/` / `tutorials/` が consumer-facing なドキュメントであるのに対し、本ファイルは **このキットを保守・拡張する開発者 (maintainer / contributor) が遵守すべき開発ガイドライン** をまとめます。

## Distribution model

- 配布物は **1 個の gh skill** (`spec-gate`)。
- インストールは GitHub CLI `gh skill` 経由:

  ```bash
  gh skill install ukitomato/spec-driven-gating-workflow spec-gate --agent <host>
  ```

- 本 skill は `/spec-gate <subcommand>` という subcommand dispatcher として動作し、4 機能 (`scan` / `bootstrap` / `migrate` / `verify`) を提供する。
- 9 個の daily workflow wrapper (`/<prefix>-spec` 等) は `gh skill` 配布対象外で、`/spec-gate bootstrap` が project-local に生成する。
- 10 個の reviewer SubAgent (`reviewer-base` + 4 generic + 5 Brownfield specialist) と 5 個の optional reviewer も bootstrap / migrate が project-local の `.claude/agents/` に書き出す。

## Key constraints

1. **agentskills.io spec 準拠**
   - 必須 frontmatter: `name` / `description`
   - オプション: `license` / `compatibility` / `metadata` / `allowed-tools`
   - `name` は kebab-case (`^[a-z][a-z0-9-]{0,63}$`)、parent directory と一致
   - `allowed-tools` は **space-separated** (例: `Read Write Bash(git:*)`)
   - `skill-creator` で SKILL.md frontmatter を validate:

     ```bash
     gh skill install anthropics/skills skill-creator
     python3 .claude/skills/skill-creator/scripts/quick_validate.py skills/spec-gate/
     ```

2. **Progressive disclosure を厳守する**
   - `skills/spec-gate/SKILL.md` (dispatcher) は **~100 行で薄く保つ**
   - 各 subcommand の詳細は `skills/spec-gate/references/commands/<name>.md` に集約
   - SubAgent body も `references/subagents/<name>.md` に外出し
   - dispatcher は `$ARGUMENTS` 判定と該当 reference の Read のみを行う

3. **SubAgent は project-local で `.claude/agents/` に書き出す**
   - gh skill 自体は `.claude/agents/` を直接配置しない (skill の責務外)
   - 各 subcommand body の Phase 0 で `${CLAUDE_SKILL_DIR}/references/subagents/<name>.md` を Read → `.claude/agents/<name>.md` に Write
   - 既存ファイルとの衝突は `AskUserQuestion` で gated

4. **Daily wrapper の `name:` は `{{prefix}}` marker を使う**
   - `references/wrappers/<name>.md` の frontmatter `name:` は `{{prefix}}-<name>` 形式
   - `/spec-gate bootstrap` が `AskUserQuestion` で確定した prefix で全 `{{prefix}}` を Edit 置換
   - 置換漏れは bootstrap の最終 Phase で `grep -rE '\{\{[a-z_]+\}\}'` 検証

5. **SubAgent 内部の wrapper 参照も `{{prefix}}-<name>` を使う**
   - `references/subagents/<name>.md` 本文中で daily wrapper を呼ぶ箇所は `/{{prefix}}-<name>` を使う
   - bootstrap がこれらも prefix で置換する (Phase 4 の Write 時に bootstrap が処理)
   - META subcommand 参照 (`/spec-gate migrate` など) は固定名なので置換しない

6. **README / docs / tutorials は最終成果物として書く**
   - 差分情報・改訂履歴を含めない
   - 「前回プランからの変更」「Renamed from X」のような注釈を書かない
   - クリーンコンテキストで読まれる前提で記述する
   - 任意の OSS ユーザがフォーク・参照する想定で、固有のプロジェクト名・社内用語・個人パス等を含めない

## Repository layout

```
/
├── README.md                          # consumer-facing 入口
├── LICENSE                            # MIT
├── CLAUDE.md                          # このファイル (maintainer 向け)
├── CHANGELOG.md                       # SemVer 履歴
├── docs/                              # consumer 向け詳細ドキュメント
│   ├── architecture.md
│   ├── adoption-guide.md
│   └── customization-guide.md
├── tutorials/                         # 動く walkthrough (README 形式)
│   ├── greenfield-walkthrough.md
│   ├── brownfield-migration.md
│   └── custom-reviewer.md
└── skills/
    └── spec-gate/                     # 唯一の gh skill installable
        ├── SKILL.md                   # dispatcher (~100 行)
        ├── references/
        │   ├── commands/              # 4 subcommand body
        │   ├── subagents/             # 10 SubAgent (reviewer-base + 4 generic + 5 brownfield)
        │   ├── wrappers/              # 9 daily wrapper template ({{prefix}} marker)
        │   ├── reviewers-optional/    # 5 optional reviewer body
        │   ├── docs-templates/        # Constitution / Charter / Glossary 雛形
        │   ├── memory/                # AGENTS.md / CLAUDE.md merge template
        │   └── lang/                  # ja.json / en.json
        └── scripts/                   # 生成 wrapper が `.specify/scripts/` から呼ぶ helper
            ├── spec-resolve.sh
            └── status-transition.sh
```

## Development workflow

このリポジトリ自身の開発には Spec-Driven Gating Workflow を **使わない** (bootstrap の chicken-and-egg 問題があるため)。代わりに以下:

1. ローカル install + 動作検証:

   ```bash
   gh skill install --from-local ./skills/spec-gate --agent claude-code
   # 別ディレクトリの test-project で /spec-gate scan / bootstrap / verify を実行して dispatcher の挙動を確認
   ```

2. SKILL.md frontmatter の static validate:

   ```bash
   gh skill install anthropics/skills skill-creator
   python3 .claude/skills/skill-creator/scripts/quick_validate.py skills/spec-gate/
   ```

3. PR review は人間レビュー + 上記 lint で代用する。

## Known limitations

### 1. `disable-model-invocation` field は agentskills.io 厳格 spec 外

`disable-model-invocation: true` は Claude Code 拡張で、agentskills.io spec の `quick_validate.py` では "unexpected key" として警告される。

trade-off:
- **残す (現状)**: Claude Code で model 自動起動を防ぐ。意図しない `/<prefix>-done` の auto-trigger 等を防止
- **削除**: agentskills.io 100% 準拠だが、Claude Code で誤起動リスク

本 skill では Claude Code が主 host のため top-level に残す。Cursor / GitHub Copilot 等の host は本 field を ignore するだけで害はない。`gh skill publish --dry-run` で validation エラーになる場合は `metadata` 配下に移動を検討する。

### 2. `references/wrappers/*.md` の template は agentskills.io validator の対象外

`references/wrappers/*.md` は bootstrap subcommand が `{{prefix}}` 等の marker を確定値に置換して `.claude/skills/<prefix>-*/SKILL.md` として Write するための **template** であり、`gh skill install` 時には deploy されない reference asset 扱い。`skill-creator` の `quick_validate.py` は `skills/spec-gate/SKILL.md` のみを検証対象とするため、wrapper template の `name: {{prefix}}-spec` 等を validate エラーにする必要はない。

## References

- [agentskills.io specification](https://agentskills.io/specification)
- [Claude Code Agent Skills overview](https://docs.claude.com/en/docs/claude-code/skills)
- [Cursor Skills documentation](https://cursor.com/docs/skills)
- [GitHub CLI `gh skill` manual](https://cli.github.com/manual/gh_skill)
- [anthropics/skills](https://github.com/anthropics/skills) — `skill-creator` を含む公式 skill 集
