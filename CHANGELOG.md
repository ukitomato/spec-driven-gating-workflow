# Changelog

All notable changes to Spec-Driven Gating Workflow will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] — 2026-05-23

Post-trial revision driven by the menteech-platform deployment review (see `docs/workflow-revision-notes.md` in the trial repo). Addresses 30+ defects across Blocker / High / Medium severities. **Breaking changes**: re-bootstrap required for existing applied repos.

### Added

- **`scripts/gate-common.sh`** — shared helper for all 9 wrappers: Phase 0 dedup, atomic spec-id allocation (flock/mkdir-lock fallback), cascade enforcement, viewpoint coverage check, JSON verdict emit/validate, agents registry validation, timeout-bounded subprocess, UTF-8 grapheme-aware subject truncation. Unit tests in `scripts/tests/`.
- **3 new actor subagents** (resolves prompt-only references in v0.1.0):
  - `implementer.md` — code-gate auto-fix loop core actor
  - `lint-agent.md` — JSON-structured lint runner
  - `test-agent.md` — JSON-structured test runner
- **`references/agents-registry.template.yaml`** — 18-agent registry (5 reviewer + 5 brownfield specialist + 3 actor + 5 optional). Installed by bootstrap as `.specify/.agents-registry.yaml`. `gate_common::registry_assert_agent` validates before subagent invoke.
- **`references/id-registry.template.json`** — global namespace for `bf_ids` / `sf_ids` (Brownfield Feature IDs / Structural Feature IDs). Atomic atomic allocation via `.specify/.id-registry.json`.
- **`status-transition.sh --gate-transition / --validate-verdict / --legacy` modes** — JSON verdict gating, hard-gate enforcement.
- **JSON verdict emission for all 3 gates** — `<spec_dir>/.gate-verdict-{design,code,pr}.json` with severity counts, FR coverage, touched-files SHA, viewpoint coverage, dedup log. Machine-checkable, schema-validated.
- **`constitution-template.md` fence markers** — `<!-- BOOTSTRAP_SECTION_START principle=N -->` / `<!-- MIGRATE_SECTION_START principle=N -->` for section-ownership-preserving merge between bootstrap-draft and migrate-draft.
- **`verify` Phase 3.5** — NON-NEGOTIABLE Principle existing_violations enumeration. `> 0` causes `overall_status: fail`.
- **`verify` Phase 4.5b** — orchestration runtime check (`task` / `nx` / `turbo` 等不在で `dev-ready: fail`).
- **`verify` Phase 4.6** — Static URL existence check (external service return URL 404 detection, e.g., Stripe Connect onboarding).
- **`migrate` Phase 4 NON-NEGOTIABLE Principle adoption AskUserQuestion gate** — 各 Principle 採用時に既存違反件数を提示、(a) 採用+別 spec / (b) スコープ縮小 / (c) skip / (d) pending-review / (e) deferred-violations 保存 から選択。
- **`migrate --rollback-to <N>`** — Phase 間 snapshot による revert checkpoint。
- **`migrate --quality-floor N`** — discovery quality score 不足時の "do not migrate" exit hatch。
- **`migrate --mark-done <action-id>`** — `.specify/.migrate-progress.json` の next_actions live update。

### Changed (breaking)

- **`reviewer-base.md` quota system replaced**: 旧 "最低 3 件の Critical 必須" → A-H 8-viewpoint coverage matrix。observation-based 主義との矛盾解消、`gate_common::viewpoint_coverage_check` で機械検証。
- **`reviewer-base.md` ADR shift-left**: 全 reviewer が `status: accepted` ADR の header + Decision Outcome + Confirmation のみ読む (architecture-reviewer は全文)。design-gate でも ADR drift 検出可能に。
- **`code-gate` vs `pr-gate` scope split**: code-gate は lint/test/convention 専任、pr-gate は security/architecture/po 専任。overlap 排除、pr-gate は code-gate verdict JSON を読んで重複指摘を suppress。
- **`pr-gate --defer-remaining` removed**: 純粋 hard gate に。Critical 残存で done 不可、defer 経路なし。
- **`pr-gate` convergence rule の数学的定義**: 隣接 2 round (N, N-1) で resolved < new → halt (最小発火 round=4)。
- **`code-gate` cascade exhaustion の数学的定義**: 3 連続 iter で MUST_FIX 単調非減少 → halt (最小発火 iter=3)。
- **`code-gate` auto-fix loop が `implementer` 実体 subagent を Agent ツールで invoke** (旧仕様は prompt 上の名前のみ)。
- **`spec-reverser` output format**: 旧 `User Story (recovered)` 見出しを `Observed behavior (NOT user research)` に rename。frontmatter `story_type: observed` + `confidence: low|medium|high` 必須化。`(推定)` マーカー禁止 → `[observed]` / `[aspiration]` / `[NOT-observed]` の 3-tag system。
- **`spec-reverser` bf_ids / sf_ids self-allocate 禁止**: `.specify/.id-registry.json` 経由 atomic 採番 (global uniqueness)。
- **`charter-drafter` precedence rule fixed-order**: directory > URL > DB schema、disagree 時は AskUserQuestion 必須。
- **`charter-drafter` minimum 5-line floor**: Mission / Scope / 業務ルール 各 section。
- **`charter-drafter` CDI に `owner:` 必須**: `undecided` 許容、不在禁止。
- **`charter-drafter` Open Questions に priority 必須**: blocking / important / cosmetic。
- **`glossary-extractor` Canonical / Candidate section 分離**: `confidence: low` は必ず Candidate へ。
- **`glossary-extractor` Synonyms / Polysemy 別表**: 旧 synonym 表での誤誘導 (e.g., Rating/review) を解消。
- **`glossary-extractor` category 必須**: `business | code-convention | generic`。
- **`glossary-extractor` Open Questions ratio > 30% で warning emit**。
- **`discovery-scanner` finding category enum 必須**: `observation | gap | risk | requirement_gap`。GDPR / 個人情報保護法系の欠落は `requirement_gap` 自動分類。
- **`discovery-scanner` "確認したが追加情報なし" 禁止**: `absent: true` + reason 必須。
- **`discovery-scanner` monorepo per-workspace stack mux**: 各 workspace を独立 section、20 workspace cap で sampling。
- **`constitution-drafter` 入力 filter**: `confidence: high` の reverse spec のみを synthesize 入力に使う (循環依存緩和)。
- **`constitution-drafter` existing_violations 計算 + adoption metadata 必須**: NON-NEGOTIABLE Principle ごとに bad_pattern_grep 実行 + 件数 + paths を emit。
- **`menteech-implement --no-auto-gate` rename to `--no-auto-chain`** (1 release deprecation period)。
- **`menteech-done` Stage 5 subject truncation**: 50 byte (NOT char) cap、UTF-8 grapheme cluster aware (`gate_common::truncate_subject`)。
- **`menteech-spec` Phase 5 atomic spec-id allocation**: `gate_common::spec_id_allocate_*` 経由、race condition 解消。

### Fixed

- **Race condition in `menteech-spec` NEXT_NUM allocation** (8 並列起動で衝突発生していた問題)。
- **`reviewer-base` L31/L33 contradiction**: "3 件 Critical 必須" quota と "観察事実主義" の矛盾。
- **`overall_status: warning` の論理破綻**: NON-NEGOTIABLE 採用時の Critical 違反件数を warning として処理していた問題。
- **rev-001 dual-path conflict 等の cross-cutting issue**: migrate Phase 3 で AskUserQuestion で resolution を取る経路を追加 (carry-over として明示)。
- **menteech-design-gate Phase 3 dedup の AskUserQuestion ハング**: default-automated dedup + 確認のみの AskUserQuestion で hang 回避。

### Distribution

- gh skill install path 不変。`gh skill update --all` で更新可能。
- 既存 applied repos は **clean re-bootstrap が必須** (registry / gate-common.sh / 3 actor subagent / fence-marker template 等が新規 install されるため)。

### Known limitations

- `revise-spec` skill (charter/constitution 更新時の reverse spec reconcile) は本 release では deferred。次 release 候補。
- `spec-reverser --two-pass` agreement option は実装されたが default off (本 release は option として残置)。
- gate verdict の他 SaaS (Linear / Jira) 連携は out of MVP。
- macOS bash 3.2 互換性は最良努力 (associative array を回避した実装、`flock` 不在時の `mkdir`-lock fallback あり)。

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

[Unreleased]: https://github.com/ukitomato/spec-driven-gating-workflow/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/ukitomato/spec-driven-gating-workflow/releases/tag/v0.2.0
[0.1.0]: https://github.com/ukitomato/spec-driven-gating-workflow/releases/tag/v0.1.0
