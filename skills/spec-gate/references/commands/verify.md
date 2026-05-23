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
# 必須 file / dir リスト (チェック対象、Wave 4 で expanded)
REQUIRED:
  .specify/memory/constitution.md (or constitution.draft.md)
  .specify/templates/spec-gate/  (bootstrap が配置済)
  .specify/scripts/spec-resolve.sh  (実行可能)
  .specify/scripts/status-transition.sh  (実行可能)
  .specify/scripts/gate-common.sh  (実行可能、Wave 0 新規)
  .specify/.agents-registry.yaml  (Wave 0 新規)
  .specify/.id-registry.json  (Wave 0 新規)
  docs/discovery.md
  docs/domains/  (1+ subdirectory)
  docs/glossary.md
  .claude/skills/<prefix>-{spec,plan,tasks,design-gate,implement,code-gate,pr-gate,done,add-reviewer}/SKILL.md  (9個)
  .claude/agents/{reviewer-base,security-reviewer,architecture-reviewer,po-reviewer,convention-reviewer}.md  (5個 generic)
  .claude/agents/{implementer,lint-agent,test-agent}.md  (3個 actor、Wave 0 新規)
```

各項目について:
- 存在しなければ `fail` (Phase 1 fail = report 全体 fail)
- 存在するが `status: needs-human-review` のまま → `warning`
- `status: active` → `pass`

verification report の Phase 1 section に結果を記録 (table 形式)。

## Phase 2: 整合性検証 (Cross-Reference Consistency)

frontmatter / 参照関係の妥当性チェック。

### 2.1 spec metadata validity (Wave 5 改修 2026-05-23、resolves Menteech pilot で観察された "verify spec が YAML frontmatter を期待するが SpecKit standard は bold-field" 問題)

SpecKit standard の spec.md は **YAML frontmatter を持たず、bold-field metadata** で構成される (例: `**Feature Branch**: ...`, `**Status**: Active`, `**Domain**: ...`)。本 verify は両形式を **平等に受理**:

`specs/*/spec.md` の全件で、以下のいずれかの形式で metadata が記録されていること:

#### Form A: SpecKit bold-field metadata (推奨、SpecKit standard 準拠)

spec.md の冒頭 (見出し直後) に以下を **bold-field 形式** で記述:

```markdown
# Feature Specification: <name>

**Feature Branch**: `<NNN>-<DOM>-<slug>` (or `rev-` prefix なら brownfield 作業中)
**Created**: <YYYY-MM-DD>
**Status**: Active | Migrated | Completed
**Domain**: <domain name>
**Related Principles**: <list, optional>
**Related CDIs**: <list, optional>
```

正規表現:
- `^\*\*Feature Branch\*\*: \`?([0-9]{3}-[A-Z]+-[a-z0-9-]+|rev-[0-9]{3}-[A-Z]+-[a-z0-9-]+)\`?` で `Feature Branch` を抽出
- `^\*\*Domain\*\*: ([a-z][a-z-]*)` で domain 抽出 → `docs/domains/<domain>/charter.md` 実在確認
- `^\*\*Status\*\*: (Active|Migrated|Completed|Draft)` で status 抽出

#### Form B: YAML frontmatter (旧互換、新規 spec では非推奨)

```yaml
---
spec_id: <NNN>-<DOM>-<slug>
domain: <domain>
status: drafting | planning | tasking | implementing | reviewing | completed | migrated
targets: frontend | backend | both | null
---
```

正規表現:
- `^spec_id:\s*([0-9]{3}-[a-z-]+|rev-[0-9]{3}-[A-Z]+-[a-z-]+)`
- `^domain:\s*([a-z][a-z-]*)`
- `^status:\s*(drafting|planning|tasking|implementing|reviewing|completed|migrated)`

#### 検証ロジック

```bash
for spec in specs/*/spec.md; do
  # Form A check (priority)
  feature_branch=$(grep -E '^\*\*Feature Branch\*\*' "$spec" | head -1)
  status=$(grep -E '^\*\*Status\*\*' "$spec" | head -1)
  domain=$(grep -E '^\*\*Domain\*\*' "$spec" | head -1)

  # Fallback to Form B
  if [ -z "$feature_branch" ]; then
    feature_branch=$(awk '/^---$/{c++; next} c==1{print}' "$spec" | grep -E '^spec_id:')
    status=$(awk '/^---$/{c++; next} c==1{print}' "$spec" | grep -E '^status:')
    domain=$(awk '/^---$/{c++; next} c==1{print}' "$spec" | grep -E '^domain:')
  fi

  [ -z "$feature_branch" ] && echo "warning: $spec has neither bold-field nor YAML metadata"
  # ... domain charter 実在確認, status enum 確認
done
```

両形式とも不在なら `warning` (新規 SpecKit-day-1 spec はかなりの確率で Form A、brownfield migrate 経由は Form A の確率が高い)。

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

### 2.6 Finalize-cleanliness check (Wave 6、resolves "作業メタが SSoT に残る" 問題)

migrate Phase 6 (Finalize) が走った後の **本体 file (charter / spec / constitution / glossary / discovery) に作業メタが残っていないか** を検証。

```bash
# 検査対象 file (Phase 6 で finalize される最終 SSoT)
# 注: Phase 6 完了後は specs/rev-*/ は存在せず specs/<NNN>-<DOM>-<slug>/ に rename されている
FINAL_ARTIFACTS=(
  docs/discovery.md
  docs/domains/*/charter.md
  docs/domains/_overview.md
  specs/[0-9]*/spec.md       # rev- prefix が rename 済の前提
  specs/[0-9]*/plan.md
  specs/[0-9]*/tasks.md
  .specify/memory/constitution.md
  docs/glossary.md
)

# rev- prefix / bf_ids / sf_ids 残存検知 (resolves "rev- が永続化する" 問題)
REV_RESIDUE_CHECK=(
  # Phase 6 後に存在すべきでない pattern
  'specs/rev-[0-9]'                # dir 名
  '^spec_id:\s*rev-'               # frontmatter
  '^bf_ids:'
  '^sf_ids:'
)

# 禁止 pattern (作業メタの残存検知)
FORBIDDEN_PATTERNS=(
  '\[observed\]'         # inline tag
  '\[aspiration\]'
  '\[NOT-observed\]'
  '\(推定\)'              # 旧マーカー
  '^story_type:'         # frontmatter
  '^confidence:'
  '^needs_human_review:'
  '^bf_ids:'
  '^sf_ids:'
  '^generated_by:'
  'BOOTSTRAP_SECTION_'
  'MIGRATE_SECTION_'
  '## Implementation evidence'
  '## Project quality score'
  '## Statistics'
  '## Existing violations summary'
)

# Migration disclaimer 残存検知 (NON-NEGOTIABLE、SpecKit 初日運用との区別不可能性が goal)
# 注: HTML comment (<!-- ... -->) は許容、markdown body text として残存しているもののみ検出
DISCLAIMER_PATTERNS=(
  'Migrated from existing implementation'
  '本書は既存コードと git 履歴から逆生成された'
  '本書は逆生成'
  'reverse-engineered from existing'
  'Recovered from code observation'
  'Validate against current architecture'
  'spec-reverser が生成'
  'This document records OBSERVED BEHAVIOR'
  'Plan reverse-engineered'
  'All tasks are pre-checked since the feature is already implemented'
  'NOT user research'
)

# code-centric 参照の検出 (warning レベル、完全禁止は難しいため heuristic)
WARNING_PATTERNS=(
  ':[0-9]+\)'    # path:line 形式 (e.g., "lib/auth.ts:42")
  ':[0-9]+-[0-9]+\)'  # path:line-line range
)
```

各 final artifact に対して:

1. `FORBIDDEN_PATTERNS` に該当する行があれば **`fail`** (severity: high)
2. `WARNING_PATTERNS` に該当する行があれば `warning` (path:line が説明上必要な場合があるため)
3. `.migration-trace.md` ファイルの **対応存在** をチェック:
   - finalized artifact (e.g., `docs/domains/<name>/charter.md`) があるが対応する `.migration-trace.md` が **無い** → `warning` ("migrate Phase 6 を経由していない可能性")
   - `.migration-trace.md` 自身は本検査の対象外 (作業メタ込みで OK)
4. **`rev-` prefix 残存検査** (NON-NEGOTIABLE):
   - `find specs/ -type d -name 'rev-*'` で 1 件以上 → **`fail`** ("Phase 6 finalize の rev- rename が走っていない")
   - `grep -rn 'spec_id:\s*rev-' specs/` で 1 件以上 → **`fail`**
   - `grep -rn '^bf_ids:\|^sf_ids:' specs/ --include='spec.md' --include='plan.md' --include='tasks.md'` で 1 件以上 → **`fail`** (`.migration-trace.md` は除外)
   - cross-reference 残存: `grep -rn 'rev-[0-9]' docs/ README.md CHANGELOG.md` で 1 件以上 (`.migration-trace.md` を除く) → **`fail`** ("rename 時の参照書換漏れ")
5. **frontmatter cleanliness 検査**: `spec.md` の frontmatter 内に `story_type:` / `confidence:` / `needs_human_review:` / `generated_by:` のいずれかが残存 → **`fail`**
6. **Disclaimer / migration language 残存検査** (NON-NEGOTIABLE、resolves "SpecKit 初日運用と区別がつく" 問題):
   - 各 final artifact について `DISCLAIMER_PATTERNS` を `grep -F` で検査 (`.migration-trace.md` は除外)
   - HTML comment 内 (`<!-- ... -->`) は対象外 (renderer 上不可視のため許容)
   - 検出 1 件以上 → **`fail`** ("migration disclaimer が body 中に残存。Phase 6 finalize の rewrite が不完全")
7. **Feature coverage 検査** (resolves "一部しか作られない" 問題):
   - `git log --pretty=format:'%s' --all | grep -ciE '^feat\(|^feature:|implement |add '` で主要 feature commit 数を推定
   - `specs/[0-9]*/spec.md` 件数と比較し、推定 feature 数の **70% 未満なら `warning`**
   - migration trace の `## Feature enumeration` section (Phase 3.0 出力) と spec 件数を突合 (trace に列挙されたのに spec が無い → `warning`)

verify-report に Section 追加:

```markdown
## Phase 2.6: Finalize-cleanliness check

| Artifact | forbidden hits | path:line hits | trace 存在 | verdict |
|---|---|---|---|---|
| docs/discovery.md | 0 | 2 | yes | warning (2 path:line refs) |
| docs/domains/<domain>/charter.md | 3 ([aspiration], confidence:, BOOTSTRAP_SECTION_) | 5 | yes | **fail** |
| specs/<NNN>-<DOMSHORT>-<slug>/spec.md | 0 | 0 | yes | pass |
| .specify/memory/constitution.md | 1 (Existing violations summary section) | 0 | yes | **fail** |
```

`fail` 検出 → `overall_status: fail` (warning に降格しない、resolves SSoT 品質要件)。

修正案内: "Phase 6 (Finalize) を再実行してください: `/spec-gate migrate --resume-from 6`"

### 2.5 `.specify/.agents-registry.yaml` ↔ `.claude/agents/` の一致 (Wave 4 / Wave 5 follow-up 2026-05-23)

```bash
source .specify/scripts/gate-common.sh
gate_common::registry_load   # 19 agent name (main + external) を返す
# 各 agent について registry_assert_agent を実行
```

判定ロジック (Wave 5 follow-up で 3 way classification 化、resolves #17 / #20):

1. **`agents:` main section に registered だが `.claude/agents/<name>.md` 不在** → `fail` (broken registry)
   - 例外: `agents:` の entry が `status: optional` かつ `disabled_optional_reviewers:` section にも記載あり → `pass` (project が意図的に未採用)
2. **`agents:` main section に registered + `.claude/agents/<name>.md` 実在** → `pass`
3. **`.claude/agents/<name>.md` 実在 + `agents:` main section に未登録** → 次の sub-check:
   - `external_agents:` section に登録あり + `name` 一致 → `pass` (spec-gate 外 agent として明示)
   - どちらにも記載なし → `warning` ("Unregistered agent: 適切な section (`external_agents` or `agents`) に登録してください")
4. **`disabled_optional_reviewers:` section に記載 + `.claude/agents/<name>.md` 実在** → `warning` ("disabled とマークされているが file 残存、削除推奨")

verify-report の "Phase 2.5: agent registry consistency" に table 形式で出力:

```markdown
| Agent | location | status | verdict |
|---|---|---|---|
| security-reviewer | agents (bootstrap-required) | file exists | pass |
| database-reviewer | disabled_optional_reviewers | file absent (intentional) | pass |
| openapi-contract-reviewer | disabled_optional_reviewers | file absent (intentional) | pass |
| serena-expert | external_agents | file exists | pass |
| my-custom-agent | none | file exists | **warning** (suggest: add to external_agents) |
```

### 2.5b CDI SSoT cross-check (Wave 5 follow-up 2026-05-23、resolves #19)

`.specify/cdi.yml` (CDI SSoT) と各 doc / spec の CDI 言及が整合しているか機械検証:

```python
import yaml, re, pathlib

cdi_file = pathlib.Path('.specify/cdi.yml')
if not cdi_file.exists():
    print("warning: .specify/cdi.yml not found, Phase 2.5b skipped")
    sys.exit(0)

cdi_data = yaml.safe_load(cdi_file.read_text())
registered_cdis = set((cdi_data.get('cdis') or {}).keys())

# 1. 各 CDI の owner / involves / referenced_in が埋まっているか
issues = []
for cdi_id, meta in (cdi_data.get('cdis') or {}).items():
    if not meta.get('owner') or meta.get('owner') == 'undecided':
        issues.append(f"warning: {cdi_id} has no confirmed owner")
    if not meta.get('involves'):
        issues.append(f"warning: {cdi_id} has empty involves list")
    if not meta.get('statement'):
        issues.append(f"fail: {cdi_id} has no statement")

# 2. 各 referenced_in path が実在 + 当該 CDI を実際に grep で確認
for cdi_id, meta in (cdi_data.get('cdis') or {}).items():
    for ref in (meta.get('referenced_in') or []):
        if not pathlib.Path(ref).exists():
            issues.append(f"warning: {cdi_id} references nonexistent {ref}")
        else:
            content = pathlib.Path(ref).read_text()
            if cdi_id not in content:
                issues.append(f"warning: {cdi_id} not found in {ref} body (referenced_in stale)")

# 3. doc / spec body に登場する CDI-NN がすべて SSoT に登録されているか (untracked CDI 検出)
import subprocess
found_cdis = set()
result = subprocess.run(['grep', '-rEho', 'CDI-[0-9]{1,3}',
                          'docs/', 'specs/', '.specify/memory/'],
                         capture_output=True, text=True)
for line in result.stdout.splitlines():
    m = re.match(r'^CDI-(\d+)', line)
    if m:
        found_cdis.add(f"CDI-{int(m.group(1)):02d}")

orphan = found_cdis - registered_cdis
for cdi in orphan:
    issues.append(f"warning: {cdi} referenced in body but not registered in cdi.yml")

for i in issues: print(i)
```

判定:

- `cdi.yml` 不在 → Phase 2.5b skip (greenfield project の可能性)
- `statement` 不在の CDI → `fail`
- `owner: undecided` / `involves` 空 / `referenced_in` path 不在 / body に not found → `warning`
- 本文に CDI-NN 言及あるが cdi.yml に未登録 (orphan) → `warning` ("cdi.yml に entry 追加要")

verify-report の "Phase 2.5b: CDI SSoT consistency" に table 出力:

```markdown
| CDI | owner | involves | statement | referenced_in (all exist?) | orphan? | verdict |
|---|---|---|---|---|---|---|
| CDI-01 | identity | 7 domains | filled | 4/4 exist | no | pass |
| CDI-02 | infra | 5 domains | filled | 4/4 exist | no | pass |
| CDI-10 | (undecided) | 2 domains | filled | 0/0 | no | **warning** (owner) |
```

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

### 3.3 Glossary 用語の使用状況 (全用語スキャン、resolves B-3 medium)

`docs/glossary.md` の **全 Canonical Terms + Candidate Terms** (旧仕様の 8/30 サンプリングではなく全用語) に対し:

```bash
for term in $(awk '/^### / {print $2}' docs/glossary.md); do
  count=$(grep -rc "$term" lib/ src/ apps/ packages/ 2>/dev/null | awk -F: '{s+=$2} END {print s}')
  echo "$term: $count"
done
```

各用語について:
- 0 件のコード参照 → `warning` (未使用、削除候補)
- Candidate Terms section にあって 5+ コード参照 → `warning` (canonical 昇格候補)

verify-report の "Glossary Usage Gaps" section に **全用語の参照件数 table** を必ず含める ("8/30 sampled" の旧 metric は廃止)。

### 3.4 Reverse spec `confidence` 分布 (Wave 4 新規)

`specs/rev-*/spec.md` frontmatter の `confidence` 値分布を集計:

- `high`: 件数
- `medium`: 件数
- `low`: 件数

`low` 比率が 50% を超える場合は `warning` (constitution-drafter の入力品質に懸念)。

### 3.5 NON-NEGOTIABLE Principle 採用時の Critical 違反件数 enumeration (Wave 5 改修 2026-05-23、`.specify/principle-baseline.yml` 読み込み方式)

`.specify/principle-baseline.yml` (bootstrap / migrate Phase 0 で install、constitution-drafter が live update) を SSoT として読み、各 Principle の `existing_violations` / `violation_threshold` / `level` を取得。本 file の所在は **constitution.md 本文と分離** されているため、Phase 6 Finalize 前後で読み場所が変わらない (Menteech pilot で観察された "constitution.md 本文と trace 間の所在 mismatch" 問題を解消)。

```bash
baseline_file=".specify/principle-baseline.yml"
[ ! -f "$baseline_file" ] && {
  echo "warning: principle-baseline.yml not found, Phase 3.5 skipped" >&2
  exit 0
}

# Parse YAML (yq or python -c で展開)
python3 - <<'PY'
import yaml
with open(".specify/principle-baseline.yml") as f:
    baseline = yaml.safe_load(f)

failing = []
for principle_id, meta in (baseline.get("principles") or {}).items():
    level = meta.get("level")
    violations = meta.get("existing_violations", 0)
    threshold = meta.get("violation_threshold", 0)
    if level == "NON-NEGOTIABLE" and violations > threshold:
        failing.append((principle_id, violations, threshold, meta.get("paths", [])))

if failing:
    print(f"FAIL: {len(failing)} NON-NEGOTIABLE Principle(s) over threshold")
    for p in failing:
        print(f"  Principle {p[0]}: {p[1]} > {p[2]}")
PY
```

**Hard gate** (変わらず): いずれかの NON-NEGOTIABLE Principle で `existing_violations > violation_threshold` なら `overall_status: fail`。

ただし **Brownfield baseline accommodation** (Wave 5 新規):

`.specify/principle-baseline.yml` の summary section に `baseline_snapshot_at` (Phase 4 完了日時) を保存。verify は以下の 2 区分で扱う:

1. **Baseline violations** (`existing_violations` ≤ baseline 値): "known migration baseline、remediation 進行中" として `fail` だが additional context 表示
2. **New violations** (`existing_violations` > baseline 値): **真の regression**、別途警告

判定 table を verify-report に必須記録:

```markdown
## Phase 3.5: NON-NEGOTIABLE Principle 採用時の Critical 違反件数 (`.specify/principle-baseline.yml` 経由)

| Principle | existing_violations | baseline_snapshot | violation_threshold | verdict | regression? | paths (top 5) |
|---|---|---|---|---|---|---|
| I | 4 | 4 (2026-05-23) | 0 | **fail (baseline)** | no | <module>/<file>:<line>, ... |
| II | 0 | 0 (2026-05-23) | 0 | pass | no | (none) |
| III | 6 | 4 (2026-05-23) | 0 | **fail (regression)** | yes (+2) | <module>/<file>:<line>, ... |
| **Total fail** | 2 (1 baseline、1 regression) | — | — | — | — | — |
```

採用 metadata 不在の NON-NEGOTIABLE Principle (旧仕様で書かれた Principle) は `warning` + "principle-baseline.yml 追加を推奨" 案内。

**verify pass への path**: 各 Principle の remediation feature が pr-gate を通過するたびに、本 baseline の `existing_violations` を decrement (該当 spec の Polish tasks に "Principle <I> の existing_violations を <N-1> に decrement" を含める)。0 到達で Phase 3.5 が pass に転じる。

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
[ -x .specify/scripts/gate-common.sh ] && echo "gate-common.sh OK" || echo "FAIL: not executable"
bash .specify/scripts/gate-common.sh version >/dev/null && echo "gate-common version OK" || echo "FAIL: smoke test"
```

非実行可能 → `fail` (`chmod +x` で修正可能なので修正案内も出す)。

### 4.5 Environment / secrets チェック

- `.env.example` の存在
- 環境変数 `OPENAI_API_KEY` / `ANTHROPIC_API_KEY` 等の hardcode 検出 (`grep -rE 'sk-[a-zA-Z0-9]{32,}'`)
- 検出されれば `fail` (secret leak)

### 4.5b: Orchestration runtime check (Wave 4、Wave 5 で fail → warning 降格 2026-05-23)

monorepo orchestration tool (`go-task/task`, `nx`, `turbo`, `lerna`) が `Taskfile.yml` / `nx.json` / `turbo.json` / `lerna.json` から検出された場合、その実体 binary が `which` で存在するか確認:

- `Taskfile.yml` あり、`task` 未インストール → **`warning` (dev env 依存)**
- `nx.json` あり、`nx` 未インストール → warning
- `turbo.json` あり、`turbo` 未インストール → warning

これらは **個人の dev environment 依存** であり、project 自体の健全性 (`overall_status`) を fail に降格させるべきではない (Wave 5 改修、Menteech pilot で観察された "WSL 環境で task 未インストール → 自動 fail" 問題を解消)。

ただし以下の場合は **`fail`** に escalate:

- `--strict` mode (warning も fail に escalate される)
- 同時に `package.json` の `scripts.test` / `scripts.build` 等の primary entry が **すべて** orchestration tool 経由でしか実行できない場合 (代替 entry なし、project が orchestration tool 必須設計)

verify-report の Phase 4.5b section に必須記録:

```markdown
| Tool | manifest | binary | verdict |
|---|---|---|---|
| task | Taskfile.yml (exists) | (NOT FOUND) | warning (dev env 依存、`brew install go-task` or `curl ... | sh` で解消) |
```

orchestration runtime missing は **個人環境問題** として通知、`overall_status` は他要因がなければ pass。

### 4.6: Static file 404 check (Wave 4 新規、resolves B-8 blocker)

外部 service redirect URL / OAuth callback / Stripe Connect onboarding return URL 等の **静的ファイルの物理存在** を確認:

```bash
# 例: 外部サービス連携の return URL の指す path
# 関連 module (`<service-integration-module>/<file>`) を Grep し
#   returnUrl: 'https://<project-domain>/<service>/<callback-path>'
# のような URL を抽出し、対応する static file の存在を確認

for url in $(extract_return_urls); do
  path=$(url_to_local_path "$url")  # e.g., <static-site-dir>/<service>/<callback-path>.html
  if [ ! -f "$path" ]; then
    echo "fail: $url → $path (file missing)"
  fi
done
```

検出パターン:
- 外部 PSP / 認証 federation: `returnUrl` / `refreshUrl` / `redirect_uri` / `callback_url` flags
- 設定 file 内の HTTPS path

不在 → **`fail`** (UX が成立しない、resolves B-8 "外部サービス redirect 先 404" 問題)。

verify-report の "Phase 4.6: Static URL existence check" に table 出力。

### 4.7: Workflow self-drift detection (Wave 5 新規 2026-05-23、resolves "verify spec 自体が drift する" 問題)

verify は project を verify するだけでなく、**自身が依存する spec の整合性も meta-check** する。verify の robustness を保つため、以下を検証:

| Check | Method | Verdict |
|---|---|---|
| `.specify/principle-baseline.yml` 存在 | `[ -f ]` | 不在 → warning (Phase 3.5 が skip される) |
| `.specify/.id-registry.json` 存在 | `[ -f ]` | 不在 → warning |
| `.specify/locale` 存在 (Wave 5) | `[ -f ]` | 不在 → warning ("`echo ja > .specify/locale` で作成推奨") |
| spec.md form distribution | bold-field vs YAML frontmatter の数を count | 両方混在で 30% 超なら warning ("Form 統一推奨") |
| `.migration-trace.md` companion check | brownfield migrate 経由 spec で trace 不在 | 不在 → warning ("Phase 6 が走っていない可能性") |
| Phase 6 が走った形跡 | `.specify/.migrate-snapshots/phase-6-post/` 存在 | brownfield + 不在 → warning |

各 warning は `recommend actions` section に修正 command を併記。verify は自身の信頼性に **正直であるべき** (self-drift を隠さない)。

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

## Overall status の決定 (Wave 4 で hardening)

- **ready**: 全 phase が `pass` (warning も無し)
- **warning**: 1+ warning、ただし fail なし。`--strict` モードでは **warning も fail に escalate される** (resolves item 22)
- **fail**: 以下のいずれかで決定:
  - Phase 1 / 2 で `fail` 検出
  - **Phase 2.6 で finalize-cleanliness fail** (作業メタが本体 SSoT に残存、resolves "draft が SSoT に紛れ込む" 問題)
  - **Phase 3.5 で NON-NEGOTIABLE Principle existing_violations > 0** (resolves B-3 blocker、warning に降格しない)
  - Phase 4.5b で orchestration runtime missing (resolves B-3 high)
  - Phase 4.6 で static URL 404 (resolves B-8 blocker)
  - Phase 4.5 で secret leak

`--strict` モード: warning も fail として overall_status を fail に escalate (resolves item 22 / Wave 4)。

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
6. Phase 2.5 で agent registry validation が走り unregistered list を出す
7. Phase 3.3 で全 glossary 用語の grep が実行され (8/30 サンプリングなし)、結果 table が含まれる
8. Phase 3.5 で NON-NEGOTIABLE Principle の existing_violations が enumerate され、`> 0` あれば overall_status: fail
9. Phase 4.5b で orchestration runtime (`task` 等) 不在を fail として記録
10. Phase 4.6 で external service return URL の静的 file 存在チェックを実行
