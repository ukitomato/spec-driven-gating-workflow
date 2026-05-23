# /spec-gate migrate — subcommand body

> Loaded by `skills/spec-gate/SKILL.md` (dispatcher) when the first argument is `migrate`.

既存リポジトリを **Spec-Driven Gating Workflow** に乗せるための 7-phase orchestrator。各 phase で brownfield specialist subagent (Phase 6 のみ orchestrator 直書き) を clean-context で起動し、その出力を AskUserQuestion でユーザに承認させながら、最終的に `docs/discovery.md` / `docs/domains/<name>/charter.md` / `specs/<NNN>-<DOM>-<slug>/` (SpecKit 標準 7-file: `spec / plan / research / data-model / quickstart / contracts/ / tasks`) / `.specify/memory/constitution.md` / `docs/glossary.md` を produce する。

Phase 1-5 が **working draft** を生成し、Phase 6 (Finalize) で作業メタを `.migration-trace.md` に隔離して本体を **product-centric な最終 SSoT** に rewrite する。最終 goal は「migration を知らない読み手が SpecKit 初日運用と誤認するレベルの clean さ」。

## ⚠️ Hard rules (本 command body の実行中に **毎 phase 必ず守るべき** NON-NEGOTIABLE)

Menteech pilot retrospective (2026-05-23) で観察された頻発エラーを防ぐため、本 command body を実行する orchestrator は **以下の hard rule を毎 phase で意識**:

1. **Draft Write 先行**: subagent から tool_result で draft を受け取ったら、AskUserQuestion を投げる前に **必ず Write tool で物理ファイルに書き出し + Bash で存在確認** する。tool_result の "draft を書きました" 言及だけで approve を求めるのは禁止 (詳細は本 file 73 行目 `Draft preview NON-NEGOTIABLE` section)
2. **Product-centric default**: Phase 2 (charter) / Phase 3 (spec) の subagent は **最初から product-centric** に出力する (charter-drafter / spec-reverser 仕様参照)。技術 evidence (file:line / 3-tag / クラス名) は **trace file** に分離して同時出力。Phase 6 で rewrite に頼らない設計
3. **Locale 一貫性**: invoker は subagent invocation 時に **`--locale ja` (default) / `en` を必ず明示** する。subagent 出力の body 言語と一致させる (`feedback_docs_language` pattern)
4. **rev- prefix は Phase 6 で消える前提**: Phase 3 の reverse spec dir 命名 `specs/rev-<NNN>-<DOM>-<slug>/` は **migrate 作業中の暫定**。CLAUDE.md / 各種 doc に "rev- prefix で物理分離" を **永続原則として書かない** (`.claude/skills/spec-gate/references/memory/CLAUDE.md` も Phase 6 整合に修正済、2026-05-23)
5. **NON-NEGOTIABLE Principle 採用 → existing_violations enumeration が gate**: Phase 4 で各 NON-NEGOTIABLE 候補について `bad_pattern_grep` を実行、件数 > 0 なら AskUserQuestion で defer / accept-with-tracking / decline を選ばせる。本 enumeration の結果は `.specify/principle-baseline.yml` (Phase 0 で install) に書き込み、constitution.md 本文には書き込まない (Phase 6 で trace 移送する手間を省く設計、Wave 5 改修、2026-05-23)

これらの hard rule に違反した場合、orchestrator は phase を未完了とみなし retry する。違反通知時の対処は本 file 各 phase の "Failure modes" を参照。

## Wave 4 revisions (vs v0.1.0)

| 改善点 | 該当 defect |
|---|---|
| Phase 4 finalize で **NON-NEGOTIABLE Principle 採用時の Critical 違反件数 AskUserQuestion gate を必須化** | B-5 / C-7-d |
| Phase 間 snapshot (`.specify/.migrate-snapshots/phase-N-post/`) + `--rollback-to <N>` | C-7-c |
| discovery quality floor で **"do not migrate" exit hatch** | C-7-b |
| `.migrate-progress.json` を **live update** (`--mark-done <action-id>`) | B-9 medium |
| 各 phase に `input_sha` / `output_artifacts[].sha` | B-9 low |
| Phase 0 で `.specify/.id-registry.json` を install (spec-reverser が使う) | C-5-b |

## When to invoke

- Brownfield repo に Spec-Driven Gating Workflow を **初導入** する 1 回目
- 一部 domain だけ追加で migrate する時 (`--domains <list>`)
- 中断後の再開 (`--resume-from <phase>`)
- 失敗 phase の rollback (`--rollback-to <N>`)

Greenfield (新規 repo) では本 skill は不要。`/{{prefix}}-spec` から直接開始可能。

## Inputs / Flags

| Flag | 効果 |
|---|---|
| (none) | Phase 1-7 全実行 (Discovery / Charter / Spec / Constitution / Glossary / Finalize / Final Summary) |
| `--no-reverse` | Phase 3 (Spec Reverse) を skip |
| `--no-constitution` | Phase 4 (Constitution Draft) を skip |
| `--domains a,b,c` | 指定した domain だけ Phase 2-3 を実行 |
| `--resume-from <N>` | Phase N から再開 (1-7) |
| `--rollback-to <N>` | Phase N+1 以降の artifact + progress を破棄、Phase N 完了時点に戻す (resolves C-7-c) |
| `--skip-finalize` | Phase 6 (Finalize) を skip。**テスト目的のみ、本番非推奨** (working draft のまま残るため verify Phase 2.6 で fail する) |
| `--mark-done <action-id>` | `.migrate-progress.json` の next_actions[id] を `status: done` に更新 (resolves B-9 medium) |
| `--force` | 既存 `docs/discovery.md` 等を上書き |
| `--quality-floor <N>` (default 3) | discovery quality score の最低閾値、未満で abort 推奨 (resolves C-7-b) |
| `--locale <ja\|en>` (default: auto-detect → `ja`) | 生成 doc の言語。Wave 5 新規 (2026-05-23、resolves Menteech pilot で観察された "locale 未指定で全 charter を遡及翻訳" 問題)。bootstrap が `.specify/locale` を作成済ならそれを継承、無ければ既存 CLAUDE.md / README.md の言語を auto-detect (日本語文字 > 30% で `ja`)、それでも判定不能なら default `ja`。subagent invocation で必ず明示渡し |
| `--cleanup-snapshots [keep=<N>]` (Wave 5 follow-up 2026-05-23、resolves #13) | `.specify/.migrate-snapshots/` 配下の古い phase snapshot を整理。`keep` は phase 別に保持する世代数 (default 2: 最新 + 1 つ前)。本 flag 単独実行で migrate 本体は走らず cleanup のみ。例: `--cleanup-snapshots keep=1` で最新 phase snapshot のみ残す |

## Steps

### Phase 0: Preconditions + SubAgent 配置 + registry install

1. `.specify/` ディレクトリ存在を確認 (なければ "Run `specify init` first" で halt)
2. `.claude/skills/<existing-prefix>-spec/` 存在を確認 (なければ "/spec-gate bootstrap を先に実行してください" で halt)
3. **brownfield specialist SubAgent を `.claude/agents/` に Write** (bootstrap で配置されていない 5 agents を補完):
   - `discovery-scanner.md`, `charter-drafter.md`, `spec-reverser.md`, `constitution-drafter.md`, `glossary-extractor.md`
   - `reviewer-base.md` (bootstrap 配置済の想定、無ければ Write)
4. **agents registry validation**:
   ```bash
   source .specify/scripts/gate-common.sh
   gate_common::registry_assert_agent discovery-scanner || halt
   gate_common::registry_assert_agent charter-drafter || halt
   gate_common::registry_assert_agent spec-reverser || halt
   gate_common::registry_assert_agent constitution-drafter || halt
   gate_common::registry_assert_agent glossary-extractor || halt
   ```
5. **ID registry install** (resolves C-5-b):
   - `.specify/.id-registry.json` が無ければ `${CLAUDE_SKILL_DIR}/references/id-registry.template.json` から install
5b. **Principle baseline install** (Wave 5 改修 2026-05-23、resolves "existing_violations 所在 mismatch" 問題):
   - `.specify/principle-baseline.yml` が無ければ `${CLAUDE_SKILL_DIR}/references/principle-baseline.template.yaml` から install
   - 本 file は **constitution.md 本文と分離した live baseline data**。Phase 4 (constitution-drafter) が各 NON-NEGOTIABLE Principle の observed `existing_violations` 件数を本 file に書き込む。verify Phase 3.5 はこの file を読む (constitution.md 本文ではなく)
5b-2. **CDI SSoT install** (Wave 5 follow-up 2026-05-23、resolves #19):
   - `.specify/cdi.yml` が無ければ `${CLAUDE_SKILL_DIR}/references/cdi.template.yaml` から install
   - 本 file は **Cross-Domain Invariant (CDI) の owner / statement / involves SSoT**。Phase 2 (charter-drafter) が初期 CDI entry を populate、他 doc (charter / constitution / spec) は `[[CDI-NN]]` 形式で本 file を参照する。verify Phase 2.5b で cross-check
5c. **Locale 決定** (Wave 5 改修 2026-05-23、resolves locale 未指定 friction):
   - `--locale` flag が渡されていればそれを採用
   - 無ければ `.specify/locale` (bootstrap が作成) を Read
   - 無ければ `CLAUDE.md` / `README.md` を Read し、日本語文字 (`[ぁ-ヿ一-龯]`) の比率が 30% 超なら `ja`、それ未満なら `en` を auto-detect
   - 最終 fallback: `ja` (default)
   - 確定 locale を `$LOCALE` 変数に保存、**全 subagent invocation で `--locale $LOCALE` を必ず渡す**
   - 確定 locale を `.specify/locale` に persist (次回 migrate / verify 等が継承するため)
5d. **Subagent invocation fallback pattern** (Wave 5 改修 2026-05-23、resolves "subagent runtime not yet recognized" 問題):

   bootstrap 直後の同セッションで migrate を実行する場合、Claude Code が `.claude/agents/` の新規 subagent を runtime に load していない可能性がある。本 dispatcher は以下の fallback pattern を採用:

   ```text
   for each subagent_invocation in [discovery-scanner, charter-drafter, spec-reverser, constitution-drafter, glossary-extractor]:
     attempt: Agent(subagent_type=<name>, ...)
     IF error "Unknown subagent_type":
       fallback: Agent(subagent_type=general-purpose, prompt=<embed full subagent spec>)
       NOTE in prompt: "You are acting as <name> subagent (registry not yet active).
                       Read its full spec at ${CLAUDE_SKILL_DIR}/references/subagents/<name>.md first."
   ```

   この fallback で clean-context isolation は維持される (general-purpose は新規 context で動く)。本 fallback は **Phase 2-5 すべて** で適用、Phase 6 (orchestrator 直書き) は対象外。
6. **`.specify/.migrate-snapshots/`** ディレクトリを `mkdir -p` (Phase rollback 用)
6b. **Snapshot retention policy** (Wave 5 follow-up 2026-05-23、resolves #13):

   既存 snapshot が retention 上限を超える場合、古いものを自動 archive (削除はしない、`.specify/.migrate-snapshots/.archive/` へ move)。

   - default retention: 最新 + 1 つ前の 2 世代を保持 (e.g., `phase-6-pre/` と `phase-6-post/` は両方残し、`phase-5-pre-finalize/` 等は `.archive/` へ)
   - `--cleanup-snapshots [keep=<N>]` flag で明示的 cleanup 実行 (本 phase 終了後 halt)
   - `.archive/` 内も上限 (default 5 phase 分) を超えれば oldest から削除
   - cleanup logic:

   ```bash
   # phase-<N>-{pre,post,pre-finalize}-* dir を mtime 順に list
   snapshots=$(ls -1dt .specify/.migrate-snapshots/phase-*/ 2>/dev/null)
   keep=${1:-2}   # 引数で keep 数を上書き可
   echo "$snapshots" | tail -n +"$((keep+1))" | while read -r dir; do
     mkdir -p .specify/.migrate-snapshots/.archive/
     mv "$dir" .specify/.migrate-snapshots/.archive/
   done

   # .archive/ 自身も 5 phase 分まで
   archived=$(ls -1dt .specify/.migrate-snapshots/.archive/phase-*/ 2>/dev/null)
   echo "$archived" | tail -n +6 | xargs -r rm -rf
   ```

   `--cleanup-snapshots` 単独実行時は本 step のみ走らせて完了通知 → halt (migrate 本体 skip)。
7. `.git/` がない場合は warning (commit history が読めないため Phase 1, 3 で機能制限)
8. `--resume-from` 指定があれば該当 phase の前 phase 成果物が存在することを確認
9. `--rollback-to <N>` 指定がある場合:
   - `.specify/.migrate-snapshots/phase-<N>-post/` を Read
   - Phase N+1 以降の artifact (`docs/glossary.md` / `.specify/memory/constitution.draft.md` 等) を削除
   - `.migrate-progress.json` の completed phases を切り詰め
   - 完了通知後 halt (実 migrate は別 invoke)

## Draft preview NON-NEGOTIABLE (Phase 1-5 共通、resolves "draft が見えない" 問題)

Phase 1-5 (subagent 起動 phase) の出力 (tool_result) は **必ず以下の順序で扱う**:

1. subagent から tool_result で draft を受け取る
2. **draft を該当ファイルに即 Write** (Write ツールを実行する。tool_result の中身を "draft を書きました" と言うだけでは不可):
   - Phase 1: `docs/discovery.md`
   - Phase 2: `docs/domains/<name>/charter.md` (per domain) + `docs/domains/_overview.md`
   - Phase 3: `specs/rev-<id>/` 配下に SpecKit 標準 **7-file**: `spec.md` / `plan.md` / `research.md` / `data-model.md` / `quickstart.md` / `contracts/*.md` (1 件以上) / `tasks.md` (per feature)
   - Phase 4: `.specify/memory/constitution.draft.md`
   - Phase 5: `docs/glossary.md`

Phase 6 (Finalize) は orchestrator が直接 rewrite するため、本節の "subagent → tool_result" pattern は適用外 (代わりに 6.3 step 2 の "Migration trace 生成 → 本体 rewrite → file 単位 AskUserQuestion" 手順に従う)。Phase 7 (Final Summary) は subagent も file Write もなく、サマリ表示のみ。
3. **Physical file validation (NON-NEGOTIABLE)**: Write tool 実行直後に Bash で **物理ファイルが存在することを確認**:
   ```bash
   for f in <expected files>; do
     if [ ! -f "$f" ]; then
       echo "FATAL: Write tool was not actually executed for $f" >&2
       exit 1
     fi
     # 中身が tool_result と同等 (最低限 size > 100 byte) であることも確認
     [ "$(wc -c < "$f")" -gt 100 ] || { echo "FATAL: $f is too small (Write likely failed)" >&2; exit 1; }
   done
   ```
   ファイル不在ならその場で **halt**、user に "Write tool が実行されていません。Draft preview Write step に戻ってください" と通知。AskUserQuestion を投げる前に必ずこの validation を通す。
4. **ユーザにファイル path を明示**: "Draft を <path> に書き出しました。IDE 等で確認してください。" (path は実 ls 結果から取得、捏造しない)
5. **AskUserQuestion で approve / edit / reject** を聞く
6. reject なら write した draft を削除 (or `.rejected.<TS>` に rename)、edit なら "ユーザ手動編集後に `--resume-from N` で再開してください" と案内、approve なら次 step へ

**禁止 (hard rule)**:
- ❌ tool_result の draft をファイルに書き出さずに AskUserQuestion を投げること
- ❌ Write tool 実行を **skip して "draft を書きました" と user に言う** こと (orchestrator が tool_result の存在のみで完了とみなすミス、v0.2.1 以降の頻発エラー)
- ❌ Step 3 の physical validation を skip して Phase を完了とみなすこと

これらは **本 workflow の hard 要件**。draft 内容が見えない状態で承認を求めるのは UX 違反であり、SSoT の信頼性を破壊する。

### Phase 1: Surface Scan + quality floor check

> Skip 条件: `--resume-from >= 2`

1. `discovery-scanner` subagent を Agent ツールで起動
2. tool result で受け取った draft を Read
3. **Quality floor check (resolves C-7-b)**:
   - draft の `## Project quality score` セクションを parse、`score` を取得
   - `score < --quality-floor (default 3)` なら AskUserQuestion で "Quality score (X/6) は migrate 推奨閾値未満です。続行しますか? (a) 続行 (b) abort"
   - abort 選択時は halt with "low quality 対応後に再 migrate を推奨"
4. **Draft preview Write** (NON-NEGOTIABLE):
   - `docs/discovery.md` に **即 Write** (frontmatter `status: needs-human-review` 付与)
   - User へ提示: "Discovery draft を `docs/discovery.md` に書き出しました。IDE で内容を確認してください。Tech stack: <要約 list>"
5. **AskUserQuestion** で `(a) approve / (b) edit (手動編集して --resume-from 1 で再開) / (c) reject (削除して abort)` を選択
6. reject 選択: `docs/discovery.md` を削除 + halt
7. approve 選択: `status: needs-human-review` を保持したまま次 step へ
8. **Snapshot**: `cp docs/discovery.md .specify/.migrate-snapshots/phase-1-post/discovery.md`
9. **Progress 更新**: `.specify/.migrate-progress.json` に Phase 1 完了 entry を append + `input_sha` / `output_artifacts[].sha` 計算
10. 完了通知: "Phase 1 完了。検出 tech stack: <list>。次に進みます (Phase 2)"

### Phase 2: Domain Charter Reverse

> Skip 条件: `--resume-from >= 3`

#### 2.0 Upfront design intent bundle (Wave 5 follow-up 2026-05-23、resolves #12)

`charter-drafter` を起動する **前** に、Phase 2 全体の design intent を **1 つの multi-question AskUserQuestion bundle** で確定する。Menteech pilot で観察された "後から charter rewrite / re-decomposition / style 変更で何往復もする" friction を防ぐため:

1. **discovery.md の Tech Stack + Domain 候補 (charter-drafter pre-scan)** を user に提示
2. **以下の 4 項目を 1 つの AskUserQuestion で同時に問う** (multi-select / 4 質問の bundled form):

   - Q1: **Domain decomposition policy** — "precedence (directory > URL > DB schema) で auto-suggest した N domain を採用、または手動で増減/統合する"
     - (a) auto-suggest をそのまま採用
     - (b) 統合: 2 つ以上の domain を merge (どれを merge するか自由記述)
     - (c) 分割: 1 つの domain を 2 つ以上に split
     - (d) 名称変更のみ (decomposition は同じ)
   - Q2: **Charter style** — "charter.md は最初から product-centric で書く (file:line / クラス名は trace に分離)。問題ある場合は記述方針を変更"
     - (a) product-centric を採用 (推奨、charter-drafter default)
     - (b) 技術 evidence 込みで draft → Phase 6 で rewrite (旧設計)
     - (c) 詳細は user が directly Edit (charter-drafter は skeleton のみ)
   - Q3: **Locale 確認** — "本 phase の出力 (charter / _overview) を確認:"
     - (a) `ja` (`.specify/locale` の現値、推奨)
     - (b) `en` に変更
     - (c) その他 (user 入力)
   - Q4: **Pending domain handling** — "未着手 / 1-2 クォーター後再検討の domain がある場合の扱い:"
     - (a) `feature_status: pending` で独立 charter として配置
     - (b) 隣接 domain charter の "Open Questions" 行きで吸収
     - (c) 完全に skip (charter 不在のまま)

3. user の選択を集約し、`.specify/.migrate-progress.json` の Phase 2 entry に `design_intent_bundle: {...}` で persist
4. 以後の charter-drafter invocation / Phase 2 ステップは本 bundle の決定に従う (再質問しない)

#### 2.1 charter-drafter 起動 + atomic draft write

1. `charter-drafter` subagent を Agent ツールで起動 (context: Phase 1 の `docs/discovery.md` + Phase 2.0 で確定した design intent + `--locale $LOCALE`)
2. proposed domains 一覧を確認、各 domain の **precedence tie-break 結果** を Read (charter-drafter が "tie-break needed" でマーク、Phase 2.0 Q1 (a) の場合のみ; (b)/(c) で user-overridden の場合は本 step skip)
3. **Draft preview Write per domain** (NON-NEGOTIABLE):
   - 各 proposed domain について 2 file を **即 Write**:
     - `docs/domains/<name>/charter.md` (product-centric body、`status: needs-human-review`)
     - `docs/domains/<name>/.charter.migration-trace.md` (evidence、charter-drafter spec C 構造、Wave 5 改修)
   - `docs/domains/_overview.md` に cross-domain invariants 一覧 (本文)、`.specify/cdi.yml` に CDI ownership SSoT (Wave 5 follow-up #19) を Write
   - User へ提示: "Domain charter drafts を以下に書き出しました: <list of paths>。本体 (charter.md) はそのまま読めば product 視点、技術 evidence は `.charter.migration-trace.md` を参照してください。"

#### 2.2 Domain-by-domain review (per-domain AskUserQuestion)

4. **各 domain について AskUserQuestion**:
   - "domain `<name>` を採用するか? (yes / modify name / merge / discard / edit-and-resume)"
   - reject 選択: `docs/domains/<name>/charter.md` を `.rejected.<TS>` に rename + `.specify/cdi.yml` から該当 CDI entry を削除
5. **各 CDI について `owner: undecided` のもののみ AskUserQuestion**: owner を確定 + `.specify/cdi.yml` を Edit (`_overview.md` 本文は cdi.yml を `[[CDI-NN]]` 参照する形なので別 Edit 不要、Wave 5 follow-up #19)
6. **Snapshot**: `cp -r docs/domains/ .specify/.migrate-snapshots/phase-2-post/` + `cp .specify/cdi.yml .specify/.migrate-snapshots/phase-2-post/`
7. **Progress 更新** (`design_intent_bundle` も persist 済)
8. 完了通知

### Phase 3: Spec Reverse

> Skip 条件: `--no-reverse` または `--resume-from >= 4`

**設計原則 (resolves "一部しか作られない" 問題)**:

本 Phase は **全 confirmed domain × 全 feature** を網羅的に処理する。1 feature ずつ AskUserQuestion で止めるのではなく、**全 draft を batch 書き出してから batch review** を求める。

#### Phase 3.0: Feature enumeration (NON-NEGOTIABLE pre-step)

任意の feature を見落とすことを防ぐため、全 feature 候補を **網羅的に enumerate** してから spec-reverser を呼ぶ:

1. **各 domain charter の `User Journey` section を Read** — 各 Journey が 1 feature 候補
2. **git log を全体 scan** — significant commit / PR を抽出 (PR title / commit message から feature 名候補)
3. **dir structure を scan** — module / area / route / migration file の単位で feature 候補
4. **3 source を union + dedup** → candidate feature 一覧を生成
5. **AskUserQuestion で candidate list を提示** (multi-select、default は **全 select**):
   > "以下 N 件の feature を検出しました。reverse-engineer 対象を選択してください (default: 全選択)"
6. 選択された全 feature を **batch 処理 list** とする

未検出の feature を user が手動追加できる経路も用意 (AskUserQuestion で "Other" 入力で feature 名 + 関連 file path を受ける)。

#### Phase 3.1: Batch spec-reverser invocation

batch 処理 list の **全 feature** について順次:

1. invoker が feature の bounding box (関連 file list) を `spec-reverser` に渡す
2. `spec-reverser` が **SpecKit 標準 7-file 構成 (spec / plan / research / data-model / quickstart / contracts/ / tasks)** の draft + ID candidates を返す (2026-05-23 改訂、バグ B の解消)
3. **ID registry atomic update** (resolves C-5-b):
   - `.specify/.id-registry.json` を Read
   - spec-reverser の `bf_ids candidate` 件数だけ `bf_next` を increment、allocated map に entry 追加
   - atomic write back (`flock` 経由)
4. **Draft preview Write per feature** (NON-NEGOTIABLE、Draft preview NON-NEGOTIABLE 節 + physical validation 必須):
   - 7 file 構成で `specs/rev-<NNN>-<DOMSHORT>-<feature-slug>/` 配下に **即 Write**:
     - `spec.md` (SpecKit 標準: User Stories with priority + FR + SC + Edge Cases + Assumptions、forward-looking、3-tag marker 不可)
     - `plan.md` (Technical Context + Constitution Check + Project Structure)
     - `research.md` (**brownfield 証跡集約**: 現状実装調査 + file:line 引用 + 3-tag marker + `confidence` frontmatter)
     - `data-model.md` (Entity 定義、実装非依存)
     - `quickstart.md` (Acceptance Scenario の手動検証手順)
     - `contracts/<api>.md` (API contract、複数 file)
     - `tasks.md` (forward-looking のみ、Phase 1 Setup → Phase 2 Foundational → US1..N → Polish の構成、過去 task の `[x]` リスト不可)
   - **frontmatter ルール (2026-05-23 改訂、バグ A の解消)**:
     - `spec.md` / `plan.md` / `tasks.md` frontmatter: `spec_id` / `domain` / `status: migrated` / `needs_human_review: true` / `bf_ids` / `sf_ids` / `related_principles` / `related_cdis` のみ。`confidence` / `story_type` は **書かない**
     - `research.md` frontmatter: 作業メタ (`confidence: low|medium|high` / `story_type: observed` / `generated_by` / `generated_at`) を保持
   - Bash で物理ファイル存在 validation 必須 (各 file が Write が物理実行されたことを確認)
5. **次の feature へ進む** (per-feature AskUserQuestion なし、batch で書き出し続ける)

#### Phase 3.2: Batch coverage validation

全 feature 書き出し後、次を Bash で検証 (7-file 構成チェック):

```bash
expected_count=<Phase 3.0 で選択された feature 数>

# 各 feature dir に必須 6 file (spec/plan/research/data-model/quickstart/tasks) が揃っているか
actual_complete=0
for dir in specs/rev-*/; do
  required=(spec.md plan.md research.md data-model.md quickstart.md tasks.md)
  missing=0
  for f in "${required[@]}"; do
    [ -f "$dir/$f" ] || { missing=$((missing+1)); echo "missing: $dir/$f"; }
  done
  # contracts/ は最低 1 file 必須
  [ -d "$dir/contracts" ] && [ -n "$(ls "$dir/contracts"/*.md 2>/dev/null)" ] || { missing=$((missing+1)); echo "missing: $dir/contracts/*"; }
  [ "$missing" -eq 0 ] && actual_complete=$((actual_complete+1))
done

[ "$expected_count" -eq "$actual_complete" ] || halt "expected $expected_count complete features, got $actual_complete"
```

#### Phase 3.3: Batch review (single AskUserQuestion for all features)

書き出し完了後、user へ **全 feature の path list を一括提示**:

> "Phase 3 完了: N 件の reverse spec drafts を書き出しました。
> 
> 一覧:
>   - specs/rev-001-<DOMSHORT>-<feature-slug>/
>   - specs/rev-002-<DOMSHORT>-<feature-slug>/
>   - ...
> 
> 各 spec を IDE で確認後、batch approve を選択するか、個別に修正が必要な feature 番号を指定してください。"

AskUserQuestion (1 回):
- (a) Batch approve all → Phase 4 へ進む
- (b) Specific features need rework → user が feature 番号を入力 (e.g., "rev-001, rev-003") → 該当 feature のみ spec-reverser 再起動
- (c) Edit & resume → ユーザ手動編集後 `--resume-from 4` で続行
- (d) Reject all → 全 spec を `.rejected.<TS>` に rename + halt

#### Phase 3.4 (cleanup)

1. **rev-001 dual-path conflict 等の cross-cutting issue** は当 Phase の (b) rework フローで個別 feature として AskUserQuestion 取得 (R-13 carry-over 対策)
2. **Snapshot**: `cp -r specs/rev-* .specify/.migrate-snapshots/phase-3-post/` (各 feature dir 配下の 7 file 全部を保管)
3. **Progress 更新** (`.specify/.migrate-progress.json`):
   - feature 数、各 feature の confidence (research.md frontmatter から集計)、生成 file リスト (7 file/feature)
4. 完了通知 (次 Phase 4 + 全 spec が Phase 6 で finalize される旨を案内)

#### Phase 3 における brownfield vs greenfield の責務分離 (バグ F 対応)

- **spec.md / plan.md / tasks.md は greenfield 同等の forward-looking**: tasks.md には「これから着手する work item」のみ。過去実装の `[x]` チェックリストは禁止
- **migration 由来の "現状コード移行" task は Phase 1 (Setup) に "Migration phase" として明示**:
  - 例: `T-001 Migrate existing <old-module>/<old-file> to <new-module>/<new-file>` を Phase 1 で扱う
  - 過去実装のリファクタ task は brownfield 由来の負債解消として明示 (greenfield と区別)
- **research.md には brownfield baseline + 既知ギャップ + 技術選択の比較を集約**: forward-looking ファイル群から完全分離

#### Phase 3 における spec.md の SpecKit 準拠 (バグ A 対応、NON-NEGOTIABLE)

- spec.md は **必ず SpecKit `spec-template.md` の流儀** に従う:
  - `## User Scenarios & Testing` + `### User Story <N> - <Title> (Priority: P<N>)` + Acceptance Scenarios (Given/When/Then)
  - `## Requirements` の Functional Requirements は `System MUST` 形式
  - `## Success Criteria` の Measurable Outcomes は **technology-agnostic** で **measurable**
  - `## Assumptions`
- 旧 `Observed behavior (NOT user research)` 見出し / Implementation evidence セクション / `[observed]` 等の 3-tag marker は **spec.md body に書かない** (research.md 側で扱う)
- file:line / クラス名 / Firestore collection path / `(observed at ...)` 等は spec.md body から完全排除

### Phase 4: Constitution Draft (Principle 採用 gate、resolves B-5 / C-7-d)

> Skip 条件: `--no-constitution` または `--resume-from >= 5`

1. `constitution-drafter` subagent を起動 (context: discovery + charters + **`confidence: high` の reverse spec のみ**)
2. tool result で Principle 案 + adoption metadata (`bad_pattern_grep` / `paths` / observed `existing_violations`) を受け取る
3. 既存 `.specify/memory/constitution.draft.md` が存在:
   - bootstrap-generated (BOOTSTRAP_SECTION のみ含む) → `.bak.<TS>` 保存後、MIGRATE_SECTION を additive merge
   - 既存 MIGRATE_SECTION あり → AskUserQuestion で "上書き / merge / skip"
4. **Draft preview Write** (NON-NEGOTIABLE):
   - `.specify/memory/constitution.draft.md` の MIGRATE_SECTION 内に全 Principle 案を **即 Write** (まだ approve 前)
   - **adoption metadata (bad_pattern_grep / paths / existing_violations) は constitution.draft.md に書かず、`.specify/principle-baseline.yml` に書く** (Wave 5 改修 2026-05-23、constitution.md 本文と baseline data の分離)
   - User へ提示: "Constitution draft を `.specify/memory/constitution.draft.md` に書き出しました。各 Principle の adoption_metadata と existing_violations は `.specify/principle-baseline.yml` を確認してください。"
5. **各 Principle ごとに AskUserQuestion** (resolves B-5 / C-7-d):

   NON-NEGOTIABLE Principle で `existing_violations > 0` のとき以下を必ず提示:

   > "Principle <I> ("<name>") を採用すると **<X> 件** の既存 Critical 違反が発生します。
   >  bad_pattern_grep: `<query>`
   >  Paths (top 5): <list>
   >
   >  選択肢:
   >    (a) 採用し違反は別 spec で順次解消 → `.specify/deferred-violations.md` に list
   >    (b) スコープ縮小 (Standard / "should" 形式に降格)
   >    (c) 採用 skip
   >    (d) 後で検討 (status: pending-review として draft に残す)
   >    (e) 違反一覧を `.specify/deferred-violations.md` として保存 + 採用 (a と等価)"

   通常 Principle / `existing_violations == 0` の NON-NEGOTIABLE は単純な yes/no AskUserQuestion。

6. 不採用 (c) / pending (d) Principle は MIGRATE_SECTION から **Edit で削除** (or `<!-- skipped -->` でコメントアウト)
7. (a) / (e) 選択時は `.specify/deferred-violations.md` を生成
8. **Snapshot**: `cp .specify/memory/constitution.draft.md .specify/.migrate-snapshots/phase-4-post/`
9. **Progress 更新**: 採用 Principle 数 + 違反 enumeration 結果を記録
10. 完了通知

### Phase 5: Glossary Extraction

> Skip 条件: なし

1. `glossary-extractor` subagent を起動
2. tool result で Canonical / Candidate / Synonyms / Polysemy / Open Questions を受け取る
3. **Open Questions ratio > 30% → warning emit** (resolves B-2 high):
   > "Glossary draft has X% open questions, exceeding 30% threshold. Recommend human review before accepting as SSoT."
4. **Draft preview Write** (NON-NEGOTIABLE):
   - `docs/glossary.md` に **即 Write** (frontmatter `status: needs-human-review`、既存があれば `.bak.<TS>` 保存後 merge)
   - 全 section (Canonical Terms / Candidate Terms / Synonyms / Polysemy / Multi-language mixing / Open Questions / Statistics) を含む
   - User へ提示: "Glossary draft を `docs/glossary.md` に書き出しました。Canonical/Candidate 振り分けと Polysemy 表 (統一禁止) を確認してください。Open Questions ratio: X%"
5. **同義異語 / 多言語混在の各 group ごとに AskUserQuestion** — 結果を `docs/glossary.md` に Edit で反映
6. **Polysemy group は AskUserQuestion で「意図的層別命名か?」を確認** (B-2 high の Rating/review 問題回避) — 結果を反映
7. **Snapshot**: `cp docs/glossary.md .specify/.migrate-snapshots/phase-5-post/`
8. **Progress 更新**
9. 完了通知

### Phase 6: Finalize (作業メタ除去 + product-centric rewrite)

> Skip 条件: `--skip-finalize` (テスト目的のみ、本番では非推奨) / `--resume-from >= 7`

**目的** (resolves "draft が SSoT に紛れ込む" 問題):

Phase 1-5 の出力は **作業 evidence 込みの draft**。本 Phase で **作業メタを `.migration-trace.md` に隔離し、本文を product-centric な最終 SSoT に rewrite** する。理由:

- Charter / Spec / Constitution は migrate を忘れた後の **永続 SSoT**。code path:line / クラス名 / 行数 / git commit 等は **陳腐化** する (refactor で path が消える)
- `[observed]` / `[aspiration]` / `[NOT-observed]` / `confidence: low` / `story_type: observed` 等は **作業時の判定メタ**。最終成果物にはノイズ
- 別セッションで読み返したとき "なぜこの記述があるのか" の根拠を辿るための trace は別 file に置けば十分

### Phase 6 の最終 goal — SpecKit 初日運用と区別がつかない状態

migrate Phase 6 完了後、user が任意の artifact を読んだとき:

- **disclaimer / 逆生成言及が一切ない**: "Migrated from", "本書は逆生成", "Recovered from", "Validate against current architecture" 等の language は body から完全除去
- **frontmatter は SpecKit 通常 spec と完全同一**: 余分な field なし (`spec_id`, `domain`, `status`, `targets`, `linear` のみ)
- **dir 命名は通常 spec と同一**: `specs/NNN-DOM-slug/` (`rev-` 接頭辞なし)
- **body は user / product 視点**: code 由来の path:line / クラス名 / 関数名なし
- **`.migration-trace.md` は別ファイル**: 必要時のみ参照、通常運用では読まない

→ "この project は最初から SpecKit で運用されていた" と migration を知らない読み手が誤認するレベルの clean さが goal。

#### 6.1 Finalize 対象 artifact

| Working draft (Phase 1-5 出力) | Final SSoT | Migration trace |
|---|---|---|
| `docs/discovery.md` | `docs/discovery.md` (Build/Test/Lint コマンド + 主要 dir map のみ) | `docs/.discovery.migration-trace.md` |
| `docs/domains/<name>/charter.md` | `docs/domains/<name>/charter.md` (product-centric) | `docs/domains/<name>/.migration-trace.md` |
| `docs/domains/_overview.md` | `docs/domains/_overview.md` (CDI、所有 domain のみ) | `docs/domains/._overview.migration-trace.md` |
| **`specs/rev-NNN-DOM-slug/`** | **`specs/NNN-DOM-slug/`** (dir rename、`rev-` prefix 除去) | `specs/NNN-DOM-slug/.migration-trace.md` |
| `.specify/memory/constitution.draft.md` | `.specify/memory/constitution.md` (rename) | `.specify/memory/.constitution.migration-trace.md` |
| `docs/glossary.md` | `docs/glossary.md` (canonical + synonyms + polysemy のみ) | `docs/.glossary.migration-trace.md` |

**`rev-` prefix の rename 理由 (resolves "rev- が永続化する" 問題)**:

Migrate 後の spec は「もともと存在していた feature の完成形 SSoT」として扱われる。`rev-` prefix は **migration 作業中の区別** のためだけのもので、最終成果物には不要。`rev-` を残すと:

- 新規開発者が「これは何の rev?」と混乱する
- migration を忘れて読んだとき、特殊な spec として誤解する
- `spec-resolve.sh` 等のロジックを永遠に 2 系統サポートする負債が残る

Phase 6 で `rev-NNN-DOM-slug` → `NNN-DOM-slug` に **dir rename** し、frontmatter `spec_id` も同じく `rev-` を外す。同時に `bf_ids` / `sf_ids` を frontmatter から除去 (trace に隔離)。新規 spec の連番との衝突は `.specify/.id-registry.json` で global namespace 管理されているため発生しない。

#### 6.2 各 artifact の rewrite ルール (NON-NEGOTIABLE)

**全 artifact 共通の除去対象**:

- ❌ `path:line` 参照 (e.g., `lib/auth.ts:42 で観察`)
- ❌ クラス名 / 関数名 / 行数の直接引用
- ❌ `[observed]` / `[aspiration]` / `[NOT-observed]` インラインタグ
- ❌ `(推定)` マーカー
- ❌ `confidence: low|medium|high` frontmatter
- ❌ `story_type: observed` frontmatter
- ❌ `needs_human_review: true` frontmatter (代わりに `status: draft` を残し、人間が `status: active` に昇格)
- ❌ `bf_ids` / `sf_ids` frontmatter (migration 内部の tracking、最終では不要)
- ❌ `generated_by: /spec-gate.migrate Phase N` (作業履歴は git で追える)
- ❌ "## Implementation evidence" section
- ❌ "## Project quality score" section (discovery.md)
- ❌ "## Statistics" section (glossary.md)
- ❌ adoption_metadata の `bad_pattern_grep` / `paths` / `existing_violations` 数値 (constitution.md)
- ❌ **Disclaimer / 逆生成言及 (NON-NEGOTIABLE)**:
  - "Migrated from existing implementation"
  - "本書は既存コードと git 履歴から逆生成された" (および和文 / 英文 variant)
  - "Recovered from code observation"
  - "Validate against current architecture"
  - "spec-reverser が生成"
  - "This document records OBSERVED BEHAVIOR, NOT user research"
  - "Plan reverse-engineered from existing implementation"
  - "All tasks are pre-checked since the feature is already implemented"
  - これらが body markdown (HTML comment 以外) に残ると、SpecKit 初日運用との区別がついてしまうため絶対除去

**Charter rewrite ルール**:

1. Mission / Scope / Actors / User Journey / Business rules / KPI / Cross-domain dependencies のみ残す
2. Body は **product / UX / 機能主軸** に rewrite (LLM がコード由来の記述を business 記述に変換)
3. `[aspiration]` row → Open Questions に移送 (or 削除、本人判断)
4. `[NOT-observed]` row → 削除 (Migration trace 側に残る)
5. CDI: invariant statement + owner domain は残す、evidence path は trace に移送
6. Open Questions: `priority: blocking | important | cosmetic` 表記は残す (将来 review 対象として有用)
7. frontmatter `status: needs-human-review` → `status: draft` (人間が `active` 昇格)

**Reverse spec rewrite ルール**:

1. **`rev-` prefix rename (NON-NEGOTIABLE)**:
   - Dir rename: `specs/rev-NNN-DOM-slug/` → `specs/NNN-DOM-slug/` (`mv` で実行、Bash で)
   - frontmatter `spec_id`: `rev-NNN-DOM-slug` → `NNN-DOM-slug`
   - 他 file (charter `Related Specs:`, README, CHANGELOG 等) からの `rev-NNN-...` 参照を Grep し、新 path に書き換え (Edit で in-place)
2. 見出し `Observed behavior (NOT user research)` → `User Story` に rewrite + body を `As <role>, I want <action>, so that <value>` 形式に変換
   - `[aspiration]` から価値仮説を抽出 (charter の Mission を併用)
   - 価値仮説不明な場合は `## Open Questions` に "<feature> の価値仮説" を挙げて空欄を許容
3. FR-NNN は **観察を business requirement に書き直す**: "lib/foo.ts:42 で X 実装" → "システムは X を提供する"
4. SC-NNN は **計測可能経路を business metric に書き直す**: "prometheus.metrics:foo で計測" → "<KPI> が <閾値> 以上"
5. Implementation evidence / Edge cases observed in code section 削除 (trace に移送)
6. frontmatter `status: migrated` → `status: completed` (既に実装済の feature)
7. **`bf_ids` / `sf_ids` 削除** (trace に移送)
8. **`story_type` / `confidence` / `needs_human_review` 削除**
9. **`spec_id` の `rev-` 接頭辞削除** (上記 1 と整合)

**実装手順 (Bash + Edit/Write)**:

```bash
# 1. 各 rev- spec dir を Glob
for rev_dir in specs/rev-*/; do
  old_id=$(basename "$rev_dir")                          # 例: rev-001-<DOMSHORT>-<feature-slug>
  new_id="${old_id#rev-}"                                # 例: 001-<DOMSHORT>-<feature-slug>
  new_dir="specs/${new_id}"

  # 2. Migration trace 作成 (rename 前に、元 path で trace を保存)
  cp -r "$rev_dir" "$rev_dir.bak.$(date +%s)"            # 安全のため
  # frontmatter / 作業メタを抽出して .migration-trace.md に集約
  # (実装は Phase 6 orchestrator が LLM rewrite + grep で行う)

  # 3. dir rename
  mv "$rev_dir" "$new_dir"

  # 4. frontmatter rewrite (spec.md / plan.md / tasks.md)
  # spec_id: rev-<NNN>-<DOMSHORT>-<slug> → <NNN>-<DOMSHORT>-<slug>
  # status: migrated → completed
  # bf_ids / sf_ids / story_type / confidence / needs_human_review を削除

  # 5. cross-reference update
  grep -rln "$old_id" docs/ specs/ README.md CHANGELOG.md 2>/dev/null \
    | xargs -I{} sed -i.bak "s|$old_id|$new_id|g" {}
done
```

検証:
- `find specs/ -type d -name 'rev-*'` で 0 件
- `grep -rn 'rev-[0-9]' specs/ docs/ README.md` で 0 件 (`.migration-trace.md` を除く)
- `find specs/ -type f -name 'spec.md' -exec grep -l 'spec_id: rev-' {} \;` で 0 件

**Constitution finalize ルール**:

1. `BOOTSTRAP_SECTION_*` / `MIGRATE_SECTION_*` fence marker を **削除**、内容を merge (重複削除)
2. 各 Principle の本文 (Statement / Why / Examples / Verification) のみ残す
3. `adoption_metadata.bad_pattern_grep` / `paths` / `existing_violations` 数値 → trace に移送 (CI で検証する場所が SSoT、Principle 本文は陳腐化しない form で)
4. `## Existing violations summary` table → trace に移送 (時間とともに必ず変化、固定 table は誤誘導源)
5. frontmatter `status: draft` のまま (人間レビュー → `/speckit.constitution` で finalize)
6. ファイル名: `constitution.draft.md` → `constitution.md` に rename

**Glossary finalize ルール**:

1. `## Canonical Terms` の用語のみ残す (各用語: Definition / Domain / Synonyms / Counterexamples / Category)
2. `## Candidate Terms (要 verification)` 削除 (trace に移送)、確定したものは Canonical に昇格
3. `## Synonyms` 表は残す (canonical 決定は永続情報)
4. `## Polysemy` 表は残す (意図的層別命名、削除は誤誘導源)
5. `Used in: code path:line` 削除、`Domain: <name>` だけ残す
6. `[observed]` / `[aspiration]` タグ削除
7. `confidence` per term 削除
8. `## Statistics` section 削除
9. `## Multi-language mixing` → Constitution Principle に昇格していれば削除、未昇格なら `## Open Questions` の 1 entry

**Discovery finalize ルール**:

1. `## Build / Test / Lint` section 残す (convention-reviewer / lint-agent 等の active 依存先、永続情報)
2. `## Tech Stack` section 残す (top-level + per-workspace、framework 名のみ、版数は陳腐化しがちなので "major version" レベル)
3. `## Directory Map` section 残す (主要 top-level dir の責務のみ、深さ 1-2)
4. `## CI/CD` section 残す
5. `## Unknown / Ambiguous` 全 entry → trace に移送 (作業時の判定、永続せず)
6. `## Project quality score` 削除 (一度きりの score、陳腐化)
7. `## Flavors` section: 観察事実のみ残す (e.g., "dev / stg / prod の 3 flavor が存在")、`absent: true` 行は trace に移送

#### 6.3 Phase 6 のステップ (Wave 5 改修 2026-05-23、subagent 化、resolves "ad-hoc 進行" 問題)

1. **Pre-flight AskUserQuestion**:
   > "Phase 6 (Finalize) を開始します。`phase-6-finalizer` subagent が atomic operation として実行:
   >  - dir rename (`specs/rev-NNN/` → `specs/NNN/`)
   >  - 全 cross-reference 一括更新
   >  - constitution fence marker 除去 + adoption_metadata trace 移送
   >  - glossary / discovery の summary section trace 移送
   >  - per-artifact `.migration-trace.md` companion 生成
   >  - pre/post snapshot 自動取得
   > 続行?"

2. **`phase-6-finalizer` subagent を起動** (Agent ツール、subagent runtime fallback pattern 5d 適用):
   - context: `.specify/.migrate-progress.json` + `.specify/locale` + 全 Phase 1-5 artifact
   - flag: `--specs-prefix-to-remove rev-` (default)、`--locale $LOCALE` (Phase 0 で確定)
   - dry-run mode: `--dry-run` を最初に渡し、書き換え予定を report のみ取得 → user confirmation 後に本実行

3. **Dry-run report の AskUserQuestion**:
   > "phase-6-finalizer dry-run 結果:
   >    - dir rename: N specs
   >    - cross-ref updates: M files
   >    - fence markers to remove: K
   >    - trace files to generate: L
   >  実行しますか? (a) 実行 (b) skip (c) edit dry-run plan"

4. **本実行 + acceptance criteria self-check** (subagent 内で Step 1-10 が atomic に進行)

5. **Subagent からの report を確認**:
   - PASS の場合: progress.json 更新済の前提で次 step (Phase 7) へ
   - FAIL の場合: pre-finalize snapshot から rollback、user に修正案内

6. **完了通知**: subagent が返した transformation summary を user に表示

#### 6.4 Acceptance criteria for Phase 6

1. 全 Phase 1-5 artifact について `.migration-trace.md` が存在
2. 本体 file 内に `path:line` / `[observed]` / `[aspiration]` / `[NOT-observed]` / `(推定)` / `confidence:` / `story_type:` / `bf_ids:` / `sf_ids:` が **0 件**
3. Constitution: fence marker (`BOOTSTRAP_SECTION_*` / `MIGRATE_SECTION_*`) が 0 件
4. Charter / Spec の Mission / Scope / FR / SC が product / UX / business 主軸で記述
5. `/spec-gate verify` で finalize 後の作業メタ残存検知が pass

### Phase 7: Final summary + verify 推奨

```
✓ /spec-gate migrate 完了

  Phase 1 (Scan): docs/discovery.md (quality score: <N>/6)
  Phase 2 (Charter): docs/domains/<list>/charter.md (<N> domains, <K> CDIs)
  Phase 3 (Spec Reverse): specs/<NNN>-<DOM>-<slug>/ (<N> features × SpecKit 標準 7-file)
                          research.md confidence: high=<H> medium=<M> low=<L>
  Phase 4 (Constitution): .specify/memory/constitution.md  (Phase 6 で rename 済)
                          - Principle adopted: <list>
                          - Existing violations summary: <X> entries (trace 移送済)
                          - Deferred violations: .specify/deferred-violations.md (if any)
  Phase 5 (Glossary): docs/glossary.md
                      - Canonical: <C>, Candidate: <P>, Open Questions ratio: <%>
  Phase 6 (Finalize): 全 artifact から作業メタを除去、対応 .migration-trace.md を生成
                      - rev- prefix rename: <N> dir
                      - frontmatter cleanup: <K> file
                      - disclaimer 除去: <L> location

  次のアクション (.migrate-progress.json の next_actions[] に live update 可能):
    1. /spec-gate verify --strict で finalize 含む品質検証 (必須)
    2. 全 charter を人間レビューして status を draft → active に
    3. constitution.md を /speckit.constitution で finalize (status: active 昇格)
    4. Reverse spec (specs/<NNN>-*/) の `status: completed` を順次レビュー
    5. 新規 feature 開発時は /<prefix>-spec から開始
  
  Progress 確認: cat .specify/.migrate-progress.json
  Action 完了報告: /spec-gate migrate --mark-done <action-id>
```

## `.migrate-progress.json` schema (live updatable、resolves B-9)

```json
{
  "version": 2,
  "started_at": "<ISO>",
  "phases": [
    {
      "phase": 1,
      "name": "Surface Scan",
      "status": "completed",
      "started_at": "<ISO>",
      "completed_at": "<ISO>",
      "input_sha": "<sha256 of discovery-scanner input context>",
      "output_artifacts": [
        {"path": "docs/discovery.md", "sha": "<git blob sha>"}
      ]
    },
    {...}
  ],
  "next_actions": [
    {
      "id": "verify",
      "label": "/spec-gate verify --strict で品質検証",
      "status": "pending|in-progress|done",
      "priority": "blocking"
    },
    {
      "id": "review-charter",
      "label": "全 charter (14) を人間レビュー → status を active に",
      "status": "pending",
      "priority": "blocking",
      "items_done": 0,
      "items_total": 14
    }
  ]
}
```

`--mark-done <action-id>` で `next_actions[id].status = "done"` に更新可能 (resolves B-9 medium)。

## Idempotency + rollback

- 各 phase 完了後に `.specify/.migrate-snapshots/phase-<N>-post/` に成果物 snapshot
- `--resume-from <N>`: Phase N から再開、それ以前は再利用
- `--rollback-to <N>`: Phase N+1 以降の artifact + progress を破棄
- `--force` で全 phase の確認 prompt を skip

## Failure modes

- subagent timeout → 分割して再起動を AskUserQuestion で提案
- Quality score < threshold → abort 推奨 (resolves C-7-b)
- AskUserQuestion でユーザが domain を 0 件承認 → halt
- spec-reverser の confidence が Low ばかり → AskUserQuestion で "Phase 3 を skip しますか?"
- Phase 4 で全 Principle が `existing_violations > 0` → AskUserQuestion gate で個別判断
- agent registry validation 失敗 → halt with bootstrap 再実行案内

## Acceptance criteria

### Working draft 段階 (Phase 1-5 完了時)

1. Phase 1: `docs/discovery.md` 存在、tech stack section に少なくとも 1 件、quality score >= threshold
2. Phase 2: `docs/domains/<name>/charter.md` が少なくとも 1 件、各 charter に Mission / Scope / 業務ルール section が **最小 5 行** floor、全 CDI に `owner:` 必須
3. Phase 3 (skip でなければ): `specs/rev-*/` 配下に SpecKit 標準 **7-file** (`spec.md` / `plan.md` / `research.md` / `data-model.md` / `quickstart.md` / `contracts/*.md` 最低 1 件 / `tasks.md`) が **全 feature** 揃って 1 件以上:
   - `spec.md` / `plan.md` / `tasks.md` frontmatter: `status: migrated`, `needs_human_review: true`, `bf_ids`, `sf_ids`, `related_principles`, `related_cdis` (`confidence` / `story_type` は **書かない**、research.md に集約)
   - `research.md` frontmatter: 作業メタ (`phase: research`, `story_type: observed`, `confidence: low|medium|high`, `generated_by`, `generated_at`) を保持
   - 3-tag marker (`[observed]` / `[aspiration]` / `[NOT-observed]`) は research.md body のみで使用可
4. Phase 4 (skip でなければ): `.specify/memory/constitution.draft.md` 存在、Principle が 1 件以上、各 NON-NEGOTIABLE Principle に adoption metadata + existing_violations 集計が含まれる
5. Phase 5: `docs/glossary.md` 存在、`## Canonical Terms` と `## Candidate Terms (要 verification)` が別 section、`## Synonyms` と `## Polysemy` が別表
6. `.specify/.migrate-progress.json` v2 schema (next_actions[] が object 形式) + 各 phase に input_sha / output_artifacts[].sha
7. `.specify/.migrate-snapshots/phase-<N>-post/` が 6 phase 分存在 (Phase 1-6、Phase 7 は表示のみで artifact 変更なし)
8. `.specify/.id-registry.json` が install 済 + spec-reverser の使用後 allocated map が更新されている
9. `(推定)` マーカーが全 artifact に 0 件 (3-tag system 置換済)

### Finalize 段階 (Phase 6 完了時) — 最終 SSoT 化

10. 全 Phase 1-5 artifact について対応する `.migration-trace.md` (全 audit 込み) が存在
11. **本体 file (最終 SSoT) には作業メタが 0 件**:
   - ❌ `path:line` 参照、クラス名 / 関数名 / 行数の直接引用
   - ❌ `[observed]` / `[aspiration]` / `[NOT-observed]` / `(推定)`
   - ❌ `confidence:` / `story_type:` / `needs_human_review:` / `bf_ids:` / `sf_ids:` frontmatter
   - ❌ `BOOTSTRAP_SECTION_*` / `MIGRATE_SECTION_*` fence markers (constitution)
   - ❌ `## Implementation evidence` / `## Project quality score` / `## Statistics` section
12. Charter Mission / Scope / FR / SC が **product / UX / business 主軸** で記述
13. Reverse spec の見出しが `User Story` (旧 "Observed behavior (NOT user research)" は trace のみ)
14. `.specify/memory/constitution.draft.md` → `constitution.md` に rename
15. `/spec-gate verify` で finalize 検証 (Phase 2.6 finalize-cleanliness check) pass
