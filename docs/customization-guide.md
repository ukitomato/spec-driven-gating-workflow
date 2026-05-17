# Customization Guide

Spec-Driven Gating Workflow をプロジェクトに合わせてカスタマイズする手順。

## カスタマイズの優先順位

1. **bootstrap の設定**: prefix / lang / reviewer 構成 (最少 / 適切 / 最大 / カスタム)
2. **既存 reviewer の追加有効化**: `/<prefix>-add-reviewer --from-template <built-in>`
3. **新規 reviewer の追加**: `/<prefix>-add-reviewer <name>` (custom elicitation)
4. **個別 SKILL / SubAgent 本文の編集**: `.claude/skills/<prefix>-*/SKILL.md` / `.claude/agents/<name>.md` を直接編集
5. **新規 workflow phase 追加**: post-MVP の Phase 2+ で対応予定 (`add-wrapper`)

## 1. Prefix の変更

最初の `/spec-gate bootstrap` 実行時に AskUserQuestion で決定。後から変更する場合:

```
/spec-gate bootstrap --prefix mycompany --force
```

`--force` 必須 (既存 `<old-prefix>-*` を上書き)。本文中の参照も全て更新される。

## 2. Optional reviewer の追加

### Bootstrap での選択漏れを後から追加

bootstrap Phase 3 で「最少」を選んだ後、後から特定 reviewer を追加したい:

```
/<prefix>-add-reviewer database-reviewer --from-template database-reviewer
```

実行内容:
1. `.specify/extensions/spec-gate/reviewers-optional/database-reviewer-body.md` を Read
2. AskUserQuestion で project 固有の調整 (例: PostgreSQL / MySQL / SQLite 選択)
3. `.claude/agents/database-reviewer.md` を Write
4. `.specify/spec-gate/reviewers.yml` に entry 登録 (auto_invoke_patterns 付き)
5. 該当 file pattern を含む PR で `/<prefix>-code-gate` / `/<prefix>-pr-gate` から自動 encore

利用可能な built-in template:

| Reviewer | 自動 encore する file pattern |
|---|---|
| `database-reviewer` | `**/migrations/**`, `*.sql`, `**/schema.prisma` |
| `a11y-reviewer` | `**/*.tsx`, `**/*.jsx`, `**/*.vue`, `**/*.dart`, `**/*.html` |
| `api-performance-reviewer` | `**/api/**`, `**/routes/**`, `**/controllers/**` |
| `openapi-contract-reviewer` | `**/openapi.yaml`, `**/*.openapi.yaml`, `**/contracts/*.yaml` |
| `ux-reviewer` | UI files (a11y と同じ) |

## 3. 新規 reviewer (project 固有)

built-in にない観点 (compliance, performance for specific stack 等):

```
/<prefix>-add-reviewer hipaa-compliance-reviewer
```

LLM が AskUserQuestion で:
- 責任観点 (最低 5 件)
- scope (feature / system / both)
- severity 判定基準
- Tier-0 必読ファイル
- 使用ツール (Bash 要否)
- owner matrix (他 reviewer との重複回避)

詳細は [tutorials/custom-reviewer.md](../tutorials/custom-reviewer.md)。

## 4. 個別 SKILL / SubAgent 本文の編集

### 編集対象

- `.claude/skills/<prefix>-<name>/SKILL.md` — daily wrapper
- `.claude/agents/<name>.md` — SubAgent

### 編集 → 反映

直接ファイルを編集して保存するだけで反映される (Claude Code は live change detection)。Cursor 等の host も startup 時に再読込。

```bash
# 例: code-gate の auto-fix iter を 3 → 5 に変更
vim .claude/skills/<prefix>-code-gate/SKILL.md
# Claude Code セッション内で即時反映
```

### gh skill update との関係

`gh skill update --all` は `skills/spec-gate/` 配下 (META skill 本体) のみ更新する。プロジェクトに生成された `.claude/skills/<prefix>-*/` および `.claude/agents/*.md` は管理対象外で、編集が消えることはない。

ただし `/spec-gate bootstrap --force` を再実行すると上書きされるので注意。

## 5. gh skill のバージョン管理

### 特定バージョンに pin

```bash
gh skill install ukitomato/spec-driven-gating-workflow spec-gate \
  --agent claude-code --pin v0.1.0
```

`gh skill update --all` で skip される。

### 最新版に更新

```bash
gh skill update ukitomato/spec-driven-gating-workflow
```

tree SHA で実コンテンツの変更を検出 (バージョン番号でなく実体)。

### preview / search

```bash
# 実 install 前に内容を見る
gh skill preview ukitomato/spec-driven-gating-workflow spec-gate

# 関連 skill を探す
gh skill search spec-driven
```

## 6. 言語切替

```
/spec-gate bootstrap --lang en --force
```

SKILL 本文の `{{ lang.* }}` 参照箇所が `lang/en.json` に切り替わる (ja/en 同梱)。

## 7. CI 統合 (optional)

`/<prefix>-code-gate` の lint / test を CI でも実行:

```yaml
# .github/workflows/spec-gate.yml (例)
on: pull_request
jobs:
  gate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: |
          pnpm install && pnpm lint
          pnpm test
          # gate verdict 存在を required artifact 化
          SPEC_DIR=$(.specify/scripts/spec-resolve.sh)
          test -f "$SPEC_DIR/design-gate.md"
          test -f "$SPEC_DIR/code-gate.md"
          grep -q "Status: PASS" "$SPEC_DIR/code-gate.md"
```

merge protection rule で `spec-gate` workflow PASS を required check 化することで、人間が gate を skip して merge することを防ぐ。

## 8. アンインストール

```bash
# skill 本体を削除
gh skill remove ukitomato/spec-driven-gating-workflow

# プロジェクト固有生成物を手動削除 (gh skill 管理対象外)
rm -rf .claude/skills/<prefix>-*/
rm .claude/agents/{reviewer-base,security-reviewer,architecture-reviewer,po-reviewer,convention-reviewer}.md
rm .claude/agents/{discovery-scanner,charter-drafter,spec-reverser,constitution-drafter,glossary-extractor}.md
# .agents/skills/ が共有 dir の場合は同 dir からも削除
```

specs / docs / constitution は保持される (ユーザコンテンツのため)。

## 9. アップデート時の挙動

新バージョン install 時 (`gh skill install ... --force` または `gh skill update`):

- `skills/spec-gate/SKILL.md` 本体は更新
- 既存 wrapper / SubAgent (project-local) は影響なし
- 新規機能を試したい場合は `/spec-gate bootstrap --force` で再生成
