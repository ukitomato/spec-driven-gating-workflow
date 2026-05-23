# Changelog

All notable changes to Spec-Driven Gating Workflow will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased] — Wave 5 follow-up patches (residual friction cleanup, 2026-05-23)

Wave 5 main patch (下記) で fix した 13 件に続き、残 7 件の medium/cosmetic friction を fix。両 patch は同 release で出荷予定 (本 Unreleased 全体)。

### Highlights (Wave 5 follow-up)

1. **trace file 命名規約統一**: dash-separator (`.charter-migration-trace.md`) → dot-separator (`.charter.migration-trace.md`)。per-spec dir は従来通り `<dir>/.migration-trace.md`。SSoT for naming は新規 `meta-handling.md` の section 1.2。(resolves #11)
2. **registry の external_agents + disabled_optional_reviewers section**: `serena-expert` 等の Claude Code 既存 agent や、Firestore project で不要な `database-reviewer` 等を `agents-registry.yaml` に明示登録できる 2 つの新 section。verify Phase 2.5 は 3-way classification で warning 不発化。(resolves #17 / #20)
3. **`--cleanup-snapshots [keep=N]` flag**: `.specify/.migrate-snapshots/` の古い世代を `.archive/` に move する retention policy。default keep=2 phase 世代 + archive 5 phase 世代まで。(resolves #13)
4. **`.specify/cdi.yml` CDI SSoT**: Cross-Domain Invariant の owner / involves / statement を 1 file に集約。他 doc は `[[CDI-NN]]` 参照のみ。verify Phase 2.5b で cross-check (orphan / owner undecided 検出)。(resolves #19)
5. **`meta-handling.md` matrix**: 全 subagent / verify / orchestrator が frontmatter キーと body marker の許容範囲を一元参照する SSoT。Final SSoT / migration trace / live data の 3 区分で whitelist を定義。(resolves #18)
6. **Phase 2.0 upfront design intent bundle**: charter-drafter 起動前に Q1 decomposition / Q2 style / Q3 locale / Q4 pending-domain-handling の 4 項目を 1 つの multi-question AskUserQuestion で確定。後付けの rewrite 往復を防ぐ。(resolves #12)

### Added (follow-up)

- `references/cdi.template.yaml` — CDI ownership SSoT template。Phase 0 step 5b-2 で `.specify/cdi.yml` として install。
- `references/meta-handling.md` — frontmatter キー + body marker の許容 matrix SSoT。subagent が draft return 直前に self-check に使う。
- `agents-registry.template.yaml` に `external_agents:` / `disabled_optional_reviewers:` の 2 新 section を追記 (template-level commented example のみ、実 entry は user 編集)。
- `migrate.md` Phase 0 step 5b-2 (CDI install) / step 6b (snapshot retention policy)。
- `migrate.md` Phase 2.0 (upfront design intent bundle)。
- `migrate.md` `--cleanup-snapshots [keep=<N>]` flag。
- `verify.md` Phase 2.5b (CDI SSoT cross-check)。

### Changed (follow-up)

- trace file 命名: `.charter-migration-trace.md` → `.charter.migration-trace.md` 等 (全 5 種類)。`charter-drafter.md` / `phase-6-finalizer.md` / `migrate.md` / `verify.md` / `tutorials/brownfield-migration.md` / 本 CHANGELOG の参照を一括書換。
- `verify.md` Phase 2.5 — 3-way classification (registry main / external_agents / disabled_optional_reviewers) で warning 不発化。
- `migrate.md` Phase 2 — `2.0 upfront design intent bundle` を追加、`2.1` で charter + `.charter.migration-trace.md` の dual-write、`2.2` で domain-by-domain review (旧 step 4-9 を整理)。
- `spec-reverser.md` / `charter-drafter.md` — Pre-output Style Guard / 設計方針 section の冒頭で `../meta-handling.md` への明示参照を追加。

### Fixed (Wave 5 follow-up friction resolutions)

- **#11**: trace file 命名規約が dash と dot で混在 → dot-separator に統一。
- **#12**: charter style / locale / domain decomposition / pending-domain の各 user decision が後付けで何往復もする → Phase 2.0 で 1 つの bundle に集約。
- **#13**: `.specify/.migrate-snapshots/` の retention policy 不在 → `--cleanup-snapshots` flag + default 2 phase 世代保持。
- **#17**: `serena-expert` 等 spec-gate 外 agent が verify で "unregistered" warning → `external_agents:` section で明示登録可能に。
- **#18**: frontmatter 許容 key 判断が subagent ごとに分散 → `meta-handling.md` 1 file に集約。
- **#19**: CDI ownership / involves / statement が 4 箇所 (overview / charter / constitution / spec) に分散 → `.specify/cdi.yml` 1 file SSoT に統一、他は `[[CDI-NN]]` 参照のみ。
- **#20**: optional reviewer 未採用 (database-reviewer / openapi-contract-reviewer 等) が registry に残って stale warning → `disabled_optional_reviewers:` section で意図表示。

### Migration guide (Wave 5 follow-up; for projects on Wave 5 main)

1. trace file rename: `find docs/ .specify/ -name '.*-migration-trace.md' | while read f; do mv "$f" "${f%-migration-trace.md}.migration-trace.md"; done`
2. CDI SSoT 移行 (任意): `cp ${CLAUDE_SKILL_DIR}/references/cdi.template.yaml .specify/cdi.yml`、`docs/domains/_overview.md` から CDI 一覧を本 file に転記、`_overview.md` は `[[CDI-NN]]` 参照に書き換え。
3. registry 整理: project が非採用の optional reviewer (e.g., `database-reviewer`) を `.specify/.agents-registry.yaml` の `agents:` section から削除し、`disabled_optional_reviewers:` section に reason 付きで移動。`.claude/agents/serena-expert.md` 等の Claude Code 既存 agent は `external_agents:` section に追記。
4. snapshot cleanup: `/spec-gate migrate --cleanup-snapshots keep=2` で古い snapshot を `.archive/` に整理。

## Wave 5 main patches (2026-05-23 — included in same Unreleased)

Driven by real-world Menteech Platform brownfield migration (2026-05-23) which surfaced 20 friction points across the 7-phase orchestrator. Major refactor of subagent prompts, addition of `phase-6-finalizer` atomic actor, decoupling of Principle baseline data from `constitution.md`, and `verify` self-drift detection.

### Highlights

1. **`phase-6-finalizer` subagent (NEW)** — Phase 6 Finalize is no longer ad-hoc orchestrator scripting; it's an atomic subagent operation with pre/post snapshot, dry-run mode, and self-verify against the 5 acceptance criteria.
2. **`charter-drafter` outputs product-centric directly** — `[observed]` / `[aspiration]` / `[NOT-observed]` tags and `file:line` citations now go into a separate `.charter.migration-trace.md` companion at generation time, not retroactively in Phase 6. Eliminates the "Phase 2 produces tech-evidence-laden draft → user must full-rewrite 13 charters" friction observed in Menteech.
3. **`spec-reverser` Pre-output Style Guard (NON-NEGOTIABLE)** — every spec.md / plan.md / tasks.md / data-model.md / quickstart.md / contracts/*.md draft passes a banned-content self-check before return (3-tag markers, `(推定)`, path:line citations, disclaimer phrases, `confidence:` / `story_type:` frontmatter). research.md remains the sole brownfield-evidence sink.
4. **`.specify/principle-baseline.yml` (NEW)** — `existing_violations` / `bad_pattern_grep` / `paths` for each Principle are stored in a separate baseline file, NOT in `constitution.md` body. Resolves the "Phase 6 moves data to trace → verify Phase 3.5 loses read location" mismatch.
5. **`verify` Phase 2.1 accepts both SpecKit bold-field and YAML frontmatter** — `spec.md` no longer required to have YAML frontmatter; bold-field metadata (`**Domain**: ...`) is now equally valid (SpecKit standard).
6. **`verify` Phase 3.5 reads `principle-baseline.yml`** with **baseline-vs-regression distinction** — Brownfield-known baseline violations are reported as `fail (baseline)` (expected) while NEW violations (above baseline) are `fail (regression)` (true alert).
7. **`verify` Phase 4.5b orchestration runtime check downgraded to `warning`** — `task` / `nx` / `turbo` missing is a personal-dev-env issue, not project health. `--strict` mode still escalates.
8. **`verify` Phase 4.7 self-drift detection (NEW)** — verifies the workflow's own integrity (presence of `principle-baseline.yml` / `.id-registry.json` / `.specify/locale`, spec.md form distribution, Phase 6 snapshot existence).
9. **`--locale ja|en` flag and `.specify/locale` persistence** — bootstrap stores user's language choice; migrate / verify auto-detect from `.specify/locale` or fall back to CLAUDE.md / README.md heuristic. Subagents receive `--locale` explicitly. Resolves the "locale未指定 → 全 13 charter を遡及翻訳" friction.
10. **CLAUDE.md `rev- prefix で物理分離` instruction removed** — bootstrap and migrate Phase 6 used to contradict each other; CLAUDE.md template now states "brownfield-derived specs are identified by `.migration-trace.md` companion (rev- prefix is removed at Phase 6)".
11. **Subagent runtime fallback pattern formalized** — `migrate.md` Phase 0 step 5d documents the `Agent(subagent_type=general-purpose, prompt=<embed full spec>)` fallback when `.claude/agents/` is not yet loaded by Claude Code runtime.

### Added

- `references/subagents/phase-6-finalizer.md` — new atomic Phase 6 actor with 10-step procedure (pre-snapshot → rev- rename → cross-ref update → fence cleanup → trace generation → post-snapshot → acceptance self-check → progress.json update). Registered in `agents-registry.template.yaml`.
- `references/principle-baseline.template.yaml` — separate baseline data SSoT for `existing_violations`. Installed by bootstrap and migrate Phase 0 step 5b.
- `migrate.md` Phase 0 step 5c — locale determination (flag / `.specify/locale` / auto-detect / default `ja`).
- `migrate.md` Phase 0 step 5d — subagent invocation fallback pattern.
- `migrate.md` top-level "⚠️ Hard rules" section — 5 NON-NEGOTIABLE per-phase reminders distilled from Menteech retrospective.
- `bootstrap.md` Phase 2b — `.specify/locale` persistence.
- `verify.md` Phase 4.7 — workflow self-drift detection.
- `charter-drafter.md` — "設計方針 (NON-NEGOTIABLE)" section mandating dual-output (charter.md + .charter.migration-trace.md) at Phase 2 generation time.
- `spec-reverser.md` — "Pre-output Style Guard (NON-NEGOTIABLE)" with banned-content self-check procedure.

### Changed

- `references/memory/CLAUDE.md` (bootstrap-installed template) — line 25 changed from `**rev- prefix で物理分離**: brownfield 由来の spec は specs/rev-<NNN>-<DOM>-<slug>/ に集約` to `**brownfield 由来 spec は .migration-trace.md で識別**: Phase 6 Finalize 後、命名は新規 spec と同じ specs/<NNN>-<DOM>-<slug>/`. Resolves bootstrap-migrate contradiction.
- `verify.md` Phase 2.1 — accepts both SpecKit bold-field and YAML frontmatter (Form A / Form B equally valid). Previously only YAML.
- `verify.md` Phase 3.5 — reads from `.specify/principle-baseline.yml` instead of `.specify/memory/constitution.{md,draft.md}`. Reports baseline vs regression separately.
- `verify.md` Phase 4.5b — orchestration runtime missing downgraded from `fail` to `warning` (unless `--strict` or project-required).
- `migrate.md` Phase 4 — adoption_metadata (`bad_pattern_grep` / `paths` / `existing_violations`) is no longer written to `constitution.draft.md` body; written to `.specify/principle-baseline.yml` instead.
- `migrate.md` Phase 6 — replaced 10-step orchestrator script with `phase-6-finalizer` subagent invocation (dry-run preview → confirm → atomic execution → self-check).
- `agents-registry.template.yaml` — added `phase-6-finalizer` as 6th brownfield specialist (migrate-required).

### Fixed (Menteech pilot friction resolutions)

- **#1**: bootstrap CLAUDE.md vs migrate Phase 6 contradiction on rev- prefix.
- **#2**: charter-drafter output required user-driven full rewrite to product-centric.
- **#3**: spec-reverser output had "Reverse Engineering Document" feel; now SpecKit-day-1-compliant by construction.
- **#4**: Draft preview "Write first, then AskUserQuestion" enforced via Hard rules echo at migrate.md top.
- **#5**: existing_violations location mismatch between constitution.md body (pre-Phase 6) and .constitution.migration-trace.md (post-Phase 6).
- **#6**: subagent runtime not loaded → general-purpose fallback formalized.
- **#7**: locale未指定 → `.specify/locale` persistence + auto-detect.
- **#8**: verify Phase 2.1 YAML-only assumption.
- **#9**: Brownfield baseline forces verify fail without nuance → baseline vs regression distinction.
- **#10**: Phase 6 massive ad-hoc operation → phase-6-finalizer atomic subagent.
- **#14**: spec.md vs tasks.md frontmatter inconsistency clarified (both formats accepted).
- **#15**: orchestration runtime check personal-env issue forcing project fail.
- **#16**: verify self-drift detection (Phase 4.7) added.

### Migration guide (for projects already on 0.3.0)

To benefit from Wave 5 changes without re-bootstrapping:

1. Update CLAUDE.md (project-local copy): change `**rev- prefix で物理分離**: ...` to `**brownfield 由来 spec は .migration-trace.md で識別**: Phase 6 Finalize 後、命名は新規 spec と同じ specs/<NNN>-<DOM>-<slug>/`.
2. (Optional, brownfield-finalize-pending projects only) `cp ${CLAUDE_SKILL_DIR}/references/principle-baseline.template.yaml .specify/principle-baseline.yml`, then move `existing_violations` / `bad_pattern_grep` / `paths` from `constitution.md` body to this file.
3. (Optional) `echo ja > .specify/locale` (or `en`) to lock locale.
4. Re-run `/spec-gate verify` to see Phase 3.5 baseline-vs-regression output and Phase 4.7 self-drift report.

Full re-bootstrap is **not required**; Wave 5 changes are additive to 0.3.0 artifacts.

## [0.3.0] — 2026-05-23

Major revision driven by real-world brownfield trial. Addresses ~40 defects across Blocker / High / Medium severities, redefines the `migrate` goal to **"a state indistinguishable from SpecKit day-one operation"**, and extends `spec-reverser` output to the **SpecKit standard 7-file structure**. **Breaking changes**: re-bootstrap required for existing applied repos.

Consolidates the unreleased work between v0.1.0 and v0.3.0 (internal iterations v0.2.0–v0.2.4 were never published) into a single shippable release.

### Highlights

1. **Migrate becomes a 7-phase orchestrator with Finalize**: Phase 1–5 produce *working drafts* (with brownfield evidence). Phase 6 (new) rewrites the body to a product-centric SSoT and isolates working metadata into `.migration-trace.md`. Phase 7 prints the final summary.
2. **Spec-reverser switches to SpecKit standard 7-file output**: `spec.md` / `plan.md` / `research.md` / `data-model.md` / `quickstart.md` / `contracts/*.md` / `tasks.md`. `spec.md` / `plan.md` / `tasks.md` are forward-looking (no `file:line`, no 3-tag markers); brownfield evidence is consolidated into `research.md` only.
3. **Draft preview NON-NEGOTIABLE + physical-file validation**: each migrate Phase 1–5 must `Write` the draft to disk *before* asking the user, with a Bash-side `stat` check to defeat "I wrote the draft" misreporting.
4. **`rev-` prefix is no longer persisted**: Phase 6 renames `specs/rev-NNN-DOM-slug/` → `specs/NNN-DOM-slug/`, strips `bf_ids` / `sf_ids` / `confidence` / `story_type` / `needs_human_review` / `generated_by` from frontmatter, and removes `BOOTSTRAP_SECTION_*` / `MIGRATE_SECTION_*` fence markers from the constitution.
5. **`verify` Phase 2.6 enforces finalize-cleanliness**: any residual working metadata, disclaimer, or `rev-` prefix forces `overall_status: fail`.
6. **Cross-spec CDI contract integrity check** (`architecture-reviewer §E`): when one CDI is referenced from multiple specs' `contracts/`, sibling function signatures (input/output schema, idempotency) must match — mismatch is **Critical**.

### Added

#### Skill / orchestration

- **3 actor subagents** (resolves v0.1.0 prompt-only references): `implementer.md`, `lint-agent.md`, `test-agent.md`.
- **`scripts/gate-common.sh`** — shared helper for all wrappers: atomic spec-id allocation (`flock` / `mkdir`-lock fallback), cascade enforcement, viewpoint coverage check, JSON verdict emit / validate, agents-registry validation, UTF-8 grapheme-aware subject truncation. Unit tests in `scripts/tests/`.
- **`references/agents-registry.template.yaml`** — 18-agent registry (5 reviewer + 5 brownfield specialist + 3 actor + 5 optional). Installed by bootstrap and validated before any subagent invoke.
- **`references/id-registry.template.json`** — global namespace for `bf_ids` / `sf_ids` with atomic allocation.
- **`constitution-template.md` fence markers** — `BOOTSTRAP_SECTION_*` / `MIGRATE_SECTION_*` for section-ownership-preserving merge between bootstrap-draft and migrate-draft.
- **`status-transition.sh --gate-transition` / `--validate-verdict` modes** — hard-gate enforcement on JSON verdicts.
- **JSON verdict emission for all 3 gates** — `<spec_dir>/.gate-verdict-{design,code,pr}.json` with severity counts, FR coverage, touched-files SHA, viewpoint coverage, dedup log. Machine-checkable, schema-validated.

#### Migrate

- **Phase 3 batch flow**: `3.0 Feature enumeration` (network-completeness check) + `3.1 Batch spec-reverser invocation` + `3.2 Batch coverage validation` + `3.3 Batch review (single AskUserQuestion)`. No per-feature halt — all features are written first, then reviewed in batch.
- **Phase 4 NON-NEGOTIABLE Principle adoption gate** — per-Principle `existing_violations` count is shown and the user chooses (a) adopt + deferred-violations.md / (b) reduce scope / (c) skip / (d) pending / (e) accept-as-is.
- **Phase 6 (Finalize)** — working draft → final SSoT rewrite, with per-artifact `.migration-trace.md` isolation, dir rename, frontmatter cleanup, fence-marker removal, disclaimer scrub.
- **Phase 7 (Final Summary)** — completion report including Phase 6 finalize counts and next-action checklist.
- **Draft preview NON-NEGOTIABLE** — every Phase 1–5 must `Write` the draft and pass a Bash physical-file existence + size check before any AskUserQuestion.
- **`--rollback-to <N>`** — Phase-snapshot-based revert.
- **`--quality-floor N`** — discovery quality-score "do not migrate" exit hatch.
- **`--skip-finalize`** — test-only flag (production-discouraged; `verify` Phase 2.6 will fail).
- **`--mark-done <action-id>`** — `.migrate-progress.json next_actions[]` live update.

#### Verify

- **Phase 2.6** — Finalize-cleanliness check (working metadata / disclaimer / `rev-` prefix / feature coverage all hard-fail).
- **Phase 3.5** — NON-NEGOTIABLE Principle `existing_violations` enumeration; `> 0` ⇒ `fail`.
- **Phase 4.5b** — orchestration runtime check (`task` / `nx` / `turbo` etc. absent ⇒ `dev-ready: fail`).
- **Phase 4.6** — Static URL existence check (external service return-URL 404 detection).

#### Templates / reviewers

- **4 brownfield doc templates**: `brownfield-spec-template.md` / `brownfield-plan-template.md` / `brownfield-research-template.md` / `brownfield-tasks-template.md` (deployed by bootstrap; referenced from `spec-reverser`).
- **`architecture-reviewer §E` Cross-spec CDI contract integrity check** — multi-spec CDI contract diff is **Critical** on mismatch.
- **`charter-drafter` / `spec-reverser` working-stage notes** — clarify outputs are Phase 6-finalized later, and provide rewrite-easing guidelines for `[observed]` business-prose form.
- **`domain-charter-template.md` final-form note** — disallow code-centric prose / working metadata; charter is the persistent SSoT.
- **`bootstrap` Phase 2 subagent runtime registration notice** — placed subagents activate on the next Claude Code session; current-session dispatcher falls back to a `general-purpose` agent with embedded instructions.

### Changed (breaking)

#### Reviewer base / gates

- **`reviewer-base.md`**: replaced "minimum 3 Critical" quota with an **A–H 8-viewpoint coverage matrix** (resolves the observation-based contradiction), and shifted ADR reading to `status: accepted` ADR header + Decision Outcome + Confirmation only (`architecture-reviewer` reads full).
- **`code-gate` vs `pr-gate` scope split**: `code-gate` for lint / test / convention, `pr-gate` for security / architecture / po. `pr-gate` reads the `code-gate` verdict JSON to suppress overlap.
- **`pr-gate --defer-remaining` removed**: pure hard gate, no defer path.
- **`pr-gate` convergence rule** (mathematical): adjacent rounds N, N-1 with `resolved < new` ⇒ halt (min round 4).
- **`code-gate` cascade exhaustion** (mathematical): 3 consecutive iterations with MUST_FIX monotonically non-decreasing ⇒ halt (min iter 3).
- **`code-gate` auto-fix loop now invokes the `implementer` actor subagent** via the Agent tool (v0.1.0 had only prompt-level references).

#### Spec-reverser / brownfield specialists

- **`spec-reverser` output format**: full SpecKit standard 7-file emission (vs v0.1.0's 3-file). `spec.md` / `plan.md` / `tasks.md` are forward-looking (no `file:line`, no 3-tag markers, no `(推定)`, no `confidence` / `story_type` frontmatter). All brownfield evidence (file:line, 3-tag, `confidence`, `story_type`) lives in `research.md` only. The `Observed behavior (NOT user research)` heading lives in `research.md` only — `spec.md` uses `User Scenarios & Testing` / `User Story <N>` with priority.
- **`spec-reverser` heading hierarchy**: `## User Scenarios & Testing` / `### User Story <N> - <Title> (Priority: P<N>)` / `## Requirements` (FR `System MUST`) / `## Success Criteria` (measurable, technology-agnostic) / `## Assumptions`. SpecKit-standard throughout.
- **`spec-reverser` `tasks.md` is forward-looking only**: pre-checked `[x]` past-task lists are forbidden. Setup / Foundational / US1..N / Polish phase structure with `[P]` (parallel) and `[USX]` (story) markers.
- **`spec-reverser` `bf_ids` / `sf_ids` self-allocate forbidden**: `.specify/.id-registry.json` atomic allocation via invoker.
- **`charter-drafter` precedence rule fixed-order**: directory > URL > DB schema; disagree ⇒ AskUserQuestion mandatory.
- **`charter-drafter` minimum 5-line floor** per Mission / Scope / 業務ルール.
- **`charter-drafter` CDI `owner:` required** (`undecided` allowed, missing forbidden).
- **`charter-drafter` Open Questions priority required**: blocking / important / cosmetic.
- **`glossary-extractor` Canonical / Candidate sections separated**; `confidence: low` always Candidate.
- **`glossary-extractor` Synonyms / Polysemy as separate tables** (resolves multi-meaning false-canonicalization).
- **`glossary-extractor` category required**: business / code-convention / generic.
- **`glossary-extractor` Open Questions ratio > 30 % ⇒ warning emit**.
- **`glossary-extractor` / `constitution-drafter` input filter switched to `research.md` `confidence: high`** (consistent with the new frontmatter-location rule).
- **`discovery-scanner` finding category enum required**: observation / gap / risk / requirement_gap.
- **`discovery-scanner` "確認したが追加情報なし" forbidden**: `absent: true` + reason required.
- **`discovery-scanner` monorepo per-workspace stack mux**: per-workspace section with 20-workspace cap sampling.
- **`constitution-drafter` `existing_violations` calc + adoption metadata required**: per NON-NEGOTIABLE Principle `bad_pattern_grep` + count + paths.

#### Daily wrappers (generated with user-chosen prefix)

- **`<prefix>-implement --no-auto-gate` renamed to `--no-auto-chain`** (1-release deprecation).
- **`<prefix>-done` Stage 5 subject truncation**: 50 byte (NOT char) cap, UTF-8 grapheme-cluster aware via `gate_common::truncate_subject`.
- **`<prefix>-spec` Phase 5 atomic spec-id allocation** via `gate_common::spec_id_allocate_*`.

### Fixed

- **Spec was constructed from class names / line numbers**: spec.md `(file:line)` references / class names / 3-tag markers conflicted with SpecKit's "spec should not depend on implementation" principle. Resolved by separating into `research.md` (brownfield evidence) vs `spec.md` (forward-looking).
- **Migrate produced only a partial spec set**: 3-file output (spec / plan / tasks) lacked SpecKit's full 7-file set, breaking downstream `/speckit-implement` etc. Resolved by extending `spec-reverser` to 7-file emission.
- **"Only some features got written" hang**: per-feature AskUserQuestion in Phase 3 caused halts when a user chose "edit" on feature #1. Resolved by Phase 3.0 enumeration → 3.1 batch write → 3.3 batch review.
- **Body-level `Migrated from existing implementation` / `本書は逆生成された` disclaimers**: removed from `spec.md` / `plan.md` / `tasks.md` body; HTML-comment fallback only; `verify` Phase 2.6 hard-fails on residual disclaimers in body markdown.
- **`rev-` prefix persistence**: Phase 6 dir rename (`specs/rev-NNN-...` → `specs/NNN-...`) + frontmatter `spec_id` rev-strip + cross-reference rewrite (charter `Related Specs:` / README / CHANGELOG via grep + sed) + `bf_ids` / `sf_ids` isolation to trace. Verified by `verify` Phase 2.6.
- **"Draft 書きました" misreporting**: orchestrators reported a subagent `tool_result` as "draft written" without invoking `Write`. Resolved by a physical-file validation step (`stat` + size > 100 byte) before AskUserQuestion.
- **Subagent runtime registration timing**: bootstrap-placed `.claude/agents/*.md` are not loaded in the current Claude Code session. Resolved by a Phase 2 completion notice + `general-purpose` agent embedded-instruction fallback for subsequent phases.
- **Code-centric records in Charter / Spec aging**: `file:line` / class / function names in persistent SSoT become noise after refactor. Resolved by Phase 6 product-centric rewrite + `.migration-trace.md` isolation.
- **Constitution fence markers / Existing violations summary persistence**: `BOOTSTRAP_SECTION_*` / `MIGRATE_SECTION_*` / violation tables persisted as final SSoT. Resolved by Phase 6 merge + trace migration.
- **Reverse spec heading awkwardness**: `Observed behavior (NOT user research)` is a working-draft heading. Resolved by Phase 6 rewrite to `User Story` and the `As <role>, I want <action>, so that <value>` form.
- **NON-NEGOTIABLE adoption silent acceptance**: Critical violations were buried by `warning` status. Resolved by Phase 4 AskUserQuestion gate + `verify` Phase 3.5 hard-fail.
- **Race condition in `<prefix>-spec` NEXT_NUM allocation** (8-parallel collision). Resolved by `gate_common::spec_id_allocate_*` (`flock` / `mkdir`-lock fallback).
- **`reviewer-base.md` L31 / L33 contradiction** ("3 Critical required" quota vs observation-based principle). Resolved by viewpoint coverage matrix.
- **`overall_status: warning` logic break** (NON-NEGOTIABLE Critical violations under warning). Resolved by Phase 3.5 hard-fail.
- **Cross-cutting carry-over** (e.g., dual-path conflict in a single rev-spec): migrate Phase 3 obtains resolution via AskUserQuestion explicitly.
- **`<prefix>-design-gate` Phase 3 dedup AskUserQuestion hang**: default-automated dedup with confirmation-only AskUserQuestion.
- **Cross-spec CDI contract divergence**: when one CDI appears in 2+ specs' `contracts/`, sibling fn signatures diverged silently. `architecture-reviewer §E` adds machine-checked diff / grep with Critical verdict on mismatch.

### Distribution

- `gh skill install` path unchanged. `gh skill update --all` for upgrade.
- Existing applied repos require a **clean re-bootstrap** (registry / `gate-common.sh` / 3 actor subagents / fence-marker template / brownfield templates are newly installed).

### Migration note (from v0.1.0)

```bash
# 1. Update the skill
gh skill update --all

# 2. Re-bootstrap to install the new registry / gate-common / actor agents / templates
/spec-gate bootstrap --force

# 3. If the repo was migrated under v0.1.0 spec-reverser (3-file output), re-run
#    Phase 3 (7-file structure) and Phase 6 (finalize)
/spec-gate migrate --resume-from 3 --force
# Existing spec.md will be overwritten — manual backup recommended before --force.

# 4. Verify finalize cleanliness
/spec-gate verify --strict
```

### Known limitations

- `revise-spec` skill (charter / constitution update → reverse-spec reconcile) deferred to a future release.
- `spec-reverser --two-pass` agreement option is implemented but off by default.
- Gate-verdict integration with external SaaS (Linear / Jira) is out of scope.
- macOS bash 3.2 compatibility is best-effort (associative-array avoidance + `flock` ↔ `mkdir`-lock fallback).

## [0.1.0] — 2026-05-17

Initial release.

### Added

- `spec-gate` skill (single gh skill installable, agentskills.io spec compliant)
- 4 META subcommands dispatched by `skills/spec-gate/SKILL.md`:
  - `/spec-gate scan` — tech stack detection → `docs/discovery.md`
  - `/spec-gate bootstrap` — install 9 daily wrappers + 4 generic reviewer subagents (+ reviewer-base) + Constitution scaffold + AGENTS.md/CLAUDE.md merge, with **reviewer proposal** phase (minimum/recommended/maximum/custom)
  - `/spec-gate migrate` — Brownfield 5-phase orchestrator (Surface Scan → Domain Charter Reverse → Spec Reverse → Constitution Draft → Glossary Extraction)
  - `/spec-gate verify` — quality gate (structure / consistency / gap / dev-ready) → `docs/verify-report.md`
- 9 daily workflow wrappers (generated by bootstrap with user-chosen prefix):
  - Producers: `spec` / `plan` / `tasks` / `implement` / `done`
  - Gates: `design-gate` / `code-gate` / `pr-gate`
  - Customization: `add-reviewer`
- 10 SubAgents:
  - `reviewer-base` (shared Adversary framework)
  - 4 generic reviewers: `security-reviewer` / `architecture-reviewer` / `po-reviewer` / `convention-reviewer`
  - 5 brownfield specialists: `discovery-scanner` / `charter-drafter` / `spec-reverser` / `constitution-drafter` / `glossary-extractor`
- 5 optional reviewer templates (added on demand via `/<prefix>-add-reviewer --from-template`):
  - `database-reviewer` / `a11y-reviewer` / `api-performance-reviewer` / `openapi-contract-reviewer` / `ux-reviewer`
- Status lifecycle with hard gates: `drafting → planning → tasking → implementing → reviewing → completed`
- Multi-language support (ja / en) via `references/lang/*.json`
- Constitution / Domain Charter / Glossary templates
- AGENTS.md / CLAUDE.md merge templates with fence-marker idempotency
- Helper scripts: `spec-resolve.sh` (branch → spec dir resolution) / `status-transition.sh` (frontmatter status update)
- Documentation: `architecture.md` / `adoption-guide.md` / `customization-guide.md`
- Walkthroughs: `greenfield-walkthrough.md` / `brownfield-migration.md` / `custom-reviewer.md`

### Distribution

- Distributed via `gh skill install ukitomato/spec-driven-gating-workflow spec-gate` (GitHub CLI v2.90.0+)
- Provenance metadata auto-injected (`metadata.github-path` / `github-ref` / `github-repo` / `github-tree-sha`)
- Multi-host support: Claude Code (`.claude/skills/`) + 9 hosts sharing `.agents/skills/` (Cursor / GitHub Copilot / Codex / Gemini CLI / Antigravity / Amp / Cline / OpenCode / Warp)
- Pin / update via `gh skill update --all` with tree SHA based change detection

### Known limitations

- `disable-model-invocation` field is a Claude Code extension and not part of agentskills.io strict spec (warning from `skill-creator` `quick_validate.py`). Retained because removing it risks unintended auto-invocation in Claude Code. Cursor / Copilot / Codex etc. silently ignore.
- `add-wrapper` (adding new workflow phases that extend the status lifecycle) is out of MVP scope. Targeted for Phase 2+.
- agentskills.io catalog registration deferred (current MVP supports `gh skill install` from GitHub repo directly).

[Unreleased]: https://github.com/ukitomato/spec-driven-gating-workflow/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/ukitomato/spec-driven-gating-workflow/releases/tag/v0.3.0
[0.1.0]: https://github.com/ukitomato/spec-driven-gating-workflow/releases/tag/v0.1.0
