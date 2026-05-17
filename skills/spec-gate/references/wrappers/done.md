---
name: {{prefix}}-done
description: PR 提出の最終 wrapper。6-stage gate (tasks 100% / code-gate PASS / pr-gate Critical=0 / format / commit / push / PR create) を順に検証・実行する。外部チケット (Linear / GitHub Issue) との連携も担当。status は reviewing → completed に遷移。
disable-model-invocation: true
allowed-tools: Read Write Edit Bash Glob Grep AskUserQuestion
---

# {{prefix}}-done

PR 提出の最終 wrapper。`/{{prefix}}-pr-gate` PASS 後に手動起動。**6-stage gate** を順に検証・実行し、すべて成功で `status: reviewing → completed` に遷移。

## When to invoke

- `/{{prefix}}-pr-gate` で Critical=0 になった直後 (status: reviewing)

## Inputs

- `<spec_dir>` (optional)
- `--draft`: Draft PR として作成 (`gh pr create --draft` or `glab mr create --draft`)

## 6-Stage Gate

各 stage の失敗で halt。前 stage に戻って修正することを案内。

### Stage 1: tasks.md 100% 検証

```bash
unchecked=$(grep -cE '^\s*- \[ \]' "$spec_dir/tasks.md")
[ "$unchecked" -eq 0 ] || halt with "未完了タスクあり: <list>"
```

### Stage 2: code-gate verdict 確認

`<spec_dir>/code-gate.md` の最終 verdict が PASS であること。

### Stage 3: pr-gate verdict 確認

`<spec_dir>/pr-gate.md` (or 最新 round) の verdict が PASS (Critical=0) であること。
`--defer-remaining` で defer された場合は `<spec_dir>/deferred-findings.md` の follow-up Issue が登録済であることを confirm (リポジトリ remote が gh/glab なら API 経由で issue 存在を確認)。

### Stage 4: Format

プロジェクトの format コマンドを実行 (`docs/discovery.md` から取得):

- TypeScript → `pnpm format` (prettier / biome)
- Python → `ruff format` or `black .`
- Flutter → `dart format .`
- Go → `gofmt -w .`

format 後に diff が出ていれば AskUserQuestion で「format 結果を含めて commit しますか?」を確認。

### Stage 5: Commit

1. `git status` で staging されていない変更を確認
2. `git add` で touched-files.txt 記載のファイルを stage (or 全部)
3. Conventional Commits format で commit message を生成:
   ```
   <type>(<scope>): <subject>
   
   <body>
   
   Spec: specs/<spec_dir>/spec.md
   Linear: <PRJID>-NNN  (frontmatter linear 値、null なら omit)
   ```
   - `<type>`: feat / fix / refactor / chore (spec.md frontmatter or AskUserQuestion で決定)
   - `<scope>`: spec.md frontmatter `domain` 値
   - `<subject>`: spec.md title から 50 文字以内に整形
4. `git commit` 実行 (pre-commit hook が動く)

### Stage 6: Push + PR create

1. `git push -u origin <branch>` (upstream 未設定なら -u 付き)
2. リモートが GitHub なら `gh pr create`、GitLab なら `glab mr create` を実行
3. PR body は以下テンプレート:

   ```markdown
   ## Summary
   <spec.md の Summary section から抽出>

   ## Spec
   - Spec ID: <spec_id>
   - Domain: <domain>
   - Targets: <targets>

   ## Gates passed
   - design-gate: PASS (Critical=0)
   - code-gate: PASS (MUST_FIX=0, iterations: <N>)
   - pr-gate: PASS Round <N> (Critical=0, <defer note if any>)

   ## Files changed
   <touched-files.txt の主要ファイル>

   ## Deferred follow-ups (if any)
   <deferred-findings.md の内容>

   ---
   🤖 Generated with Spec-Driven Gating Workflow
   ```

4. `--draft` 指定があれば draft PR で create
5. 作成された PR URL を表示

### Stage 7 (任意): 外部チケット連携

spec.md frontmatter `linear:` 値が non-null なら:

- Linear: `mcp__linear-server__create_comment` で PR URL + status を投稿
- GitHub Issue: `gh issue comment` で同上
- 失敗時は warning のみ (halt しない)

### Stage 8: Status 遷移 + 完了通知

```bash
# spec.md frontmatter
status: reviewing → completed
```

```
✓ /{{prefix}}-done 完了
  - spec dir: <spec_dir>
  - PR URL: <url>
  - status: reviewing → completed
  - Linear/Issue updated: <yes/no>
```

## Idempotency

- 既に completed 状態なら "既に完了済です" を表示して終了 (overwrite しない)
- PR 再作成は本 skill の責務外 (`gh pr edit` を手動で)

## Failure modes

- 各 stage 失敗時の対応:
  - Stage 1 unchecked task → `/{{prefix}}-implement` 再実行を案内
  - Stage 2/3 verdict not PASS → 対応 gate skill を再実行
  - Stage 4 format → 手動修正
  - Stage 5 commit (pre-commit hook 失敗) → hook の指摘を表示、修正を求める
  - Stage 6 push failure → 認証 / merge conflict を案内
  - Stage 6 PR create 失敗 → リモート種別と auth を確認
  - Stage 7 外部チケット失敗 → warning のみ、本体処理は続行

## Acceptance criteria

1. すべての 6 stage が PASS している
2. PR が作成された URL が表示
3. spec.md frontmatter `status` が `completed` に遷移
4. (Linear/Issue 連携指定時) コメントが投稿されたか warning で明示
