# Custom Reviewer Walkthrough

`/<prefix>-add-reviewer` で新規 reviewer subagent を後付けで追加する 2 つの mode の実例。

## Mode A: built-in optional reviewer を有効化

bootstrap で「最少」を選んだ後 (または「適切」で漏れた reviewer を追加したい時)、5 種の built-in template (database / a11y / api-performance / openapi-contract / ux) を 1 コマンドで有効化。

### 例: database-reviewer を追加

```
/myproj-add-reviewer database-reviewer --from-template database-reviewer
```

Skill が実行:

1. `${CLAUDE_SKILL_DIR}/references/reviewers-optional/database-reviewer-body.md` を Read (gh skill が配置した skill 本体内の bundled file)
2. AskUserQuestion で tech stack 適合性を確認 (例: "PostgreSQL / MySQL / SQLite どれを対象?")
3. `.claude/agents/database-reviewer.md` を Write
4. `.specify/spec-gate/reviewers.yml` に entry を登録

`reviewers.yml` 登録例:

```yaml
reviewers:
  - name: database-reviewer
    enabled: true
    scope: system
    auto_invoke_patterns:
      - "**/migrations/**"
      - "*.sql"
      - "supabase/migrations/**"
    gates: [code-gate, pr-gate]
    source: add-reviewer-from-template
```

次回 `/myproj-code-gate` または `/myproj-pr-gate` 起動時、diff に該当 pattern が含まれていれば自動 encore される。

### 例: a11y-reviewer + ux-reviewer をまとめて

```
/myproj-add-reviewer a11y-reviewer --from-template a11y-reviewer
/myproj-add-reviewer ux-reviewer --from-template ux-reviewer
```

UI 系プロジェクトでは両方有効化推奨。`scope: system` + `auto_invoke_patterns: ['**/*.tsx', '**/*.vue', '**/*.dart']` で UI 変更を含む PR で自動 encore。

## Mode B: project 固有 reviewer を新規作成

built-in にない観点 (compliance, performance for specific stack 等) を AskUserQuestion で elicit して新規起草。

### 例: HIPAA compliance reviewer を作成

```
/myproj-add-reviewer hipaa-compliance-reviewer
```

Skill が以下を順に AskUserQuestion:

1. **責任観点 (最低 5 件)**:
   - "PHI (Protected Health Information) のログ出力検出"
   - "暗号化必須箇所 (at rest / in transit) の確認"
   - "audit log の完備"
   - "アクセス制御 (RBAC / minimum necessary)"
   - "BAA (Business Associate Agreement) 締結済外部サービスのみ使用"

2. **scope**: feature / system / both → "both"

3. **severity 判定**:
   - Critical: PHI 漏洩、暗号化欠如、audit log 欠如
   - High: minimum necessary 違反、未締結 BAA サービス使用
   - Medium: audit log の retention 不足

4. **Tier-0 必読ファイル**:
   - `<spec_dir>/spec.md` (機能スコープ)
   - `docs/compliance/hipaa.md` (もしあれば project 規約)

5. **使用ツール**: Bash 不要 (静的解析のみ)

6. **owner matrix**:
   - 本 reviewer: PHI / 暗号化 / audit log / BAA
   - 他 reviewer に委ねる: 一般的な auth → security-reviewer、UI 表示 → ux-reviewer

elicit 完了後、`reviewer-base.md` を base とした body が draft され、ユーザに承認確認。

承認後:

- `.claude/agents/hipaa-compliance-reviewer.md` を Write
- `reviewers.yml` に entry 追加

```yaml
reviewers:
  - name: hipaa-compliance-reviewer
    enabled: true
    scope: both
    auto_invoke: always   # PHI の検出は scope 関係なく毎回
    gates: [code-gate, pr-gate]
    source: add-reviewer-custom
```

### dry-run

AskUserQuestion で "即座に dry-run しますか?" に yes と答えると、最新 spec_dir に対し新 reviewer を 1 回だけ起動して出力サンプルを表示。動作確認用。

## 既存 reviewer を disable

`reviewers.yml` を直接編集:

```yaml
reviewers:
  - name: hipaa-compliance-reviewer
    enabled: false   # 一時的に外す
```

または削除:

```bash
rm .claude/agents/hipaa-compliance-reviewer.md
# .specify/spec-gate/reviewers.yml から該当 entry を削除
```

## Reviewer の更新

body を編集してから Claude Code を再起動 (live change detection が拾う):

```
1. .claude/agents/<name>.md を編集
2. Claude Code 内で `/help` 等を一度叩いて skill 再読込を強制 (任意)
3. 次の /<prefix>-code-gate / /<prefix>-pr-gate 起動から反映される
```

`gh skill update` で skill 本体 (`skills/spec-gate/`) を更新しても、project-local の `.claude/agents/*.md` は影響を受けない (gh skill 管理対象外)。

ただし `/spec-gate bootstrap --force` を実行すると generic reviewer 5 個は再生成 (上書き) されるので注意。

## Tips

- **owner matrix は厳格に**: 1 観点を複数 reviewer で扱うと指摘が重複し、`/<prefix>-pr-gate` の dedup phase が肥大化する
- **5 viewpoint 未満は受け付けない**: ad-hoc に作ると Adversary としての効力が薄れる
- **NON-NEGOTIABLE は慎重に**: severity 判定の基準を厳密にする
- **dry-run で動作確認**: 本番 gate に encore する前に sample を見る
- **bootstrap の "適切" 構成提案で先回りカバー**: bootstrap Phase 3 で tech stack に応じた optional reviewer を自動推奨するので、本コマンドは「事後追加」の手段として位置付ける
