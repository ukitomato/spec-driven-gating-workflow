---
description: "Task list for <feature> implementation (brownfield migrate)"
spec_id: rev-<NNN>-<DOMSHORT>-<feature-slug>
phase: tasks
status: migrated
---

<!--
本 frontmatter から `confidence` / `story_type` は **書かない** (research.md に集約)。
Phase 6 finalize 時に `status: migrated` / `phase:` も除去される。
-->


# Tasks: <Feature name>

**Input**: Design documents from `/specs/rev-<NNN>-.../`

**Prerequisites**: plan.md / spec.md / research.md / data-model.md / quickstart.md / contracts/

**Tests**: <必須 / オプション、Principle VI に基づき>

**Organization**: Tasks are grouped by user story to enable independent implementation and testing.

> Brownfield 由来でも本 file は **forward-looking** で書く。既存実装の rename / refactor / migration もここに含めるが、これらは Phase 1 (Setup) または専用 Migration phase で扱う。過去 task の `[x]` リスト (「既に実装済」マーキング) は **禁止**。

## Format: `[T-NNN] [P?] [USX?] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[USX]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: Setup (Shared Infrastructure + brownfield migration)

**Purpose**: Project initialization + brownfield 由来の rename / refactor 

- [ ] **T-001** Create new directory structure per plan.md
- [ ] **T-002** `[P]` Set up test scaffolding
- [ ] **T-003** `[P]` Configure linting

### Brownfield migration tasks (旧コード移行)

- [ ] **T-MNNN** Move `<old_path>` to `<new_path>` per plan.md Structure Decision
- [ ] **T-MNNN** Refactor existing `<file>` to extract <responsibility> per Principle II
- ...

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] **T-NNN** Setup <foundational module>
- [ ] **T-NNN** `[P]` Unit test for foundational module
- [ ] **T-NNN** `[P]` Setup error handling and logging infrastructure
- ...

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - <Title> (Priority: P1) 🎯 MVP

**Goal**: <Brief description of what this story delivers>

**Independent Test**: <How to verify this story works on its own (quickstart Scenario X)>

### Tests for User Story 1 (test-first)

> **NOTE**: Write these tests FIRST, ensure they FAIL before implementation

- [ ] **T-NNN** `[P]` `[US1]` Contract test for <endpoint/function> in <test path>
- [ ] **T-NNN** `[P]` `[US1]` Integration test for <user journey> in <test path>

### Implementation for User Story 1

- [ ] **T-NNN** `[P]` `[US1]` Create <Entity1> model in <src path>
- [ ] **T-NNN** `[US1]` Implement <Service> in <src path>
- [ ] **T-NNN** `[US1]` Implement <endpoint/feature> in <src path>
- [ ] **T-NNN** `[US1]` Add validation and error handling
- [ ] **T-NNN** `[US1]` Add logging for user story 1 operations

**Checkpoint**: At this point, User Story 1 should be fully functional and testable independently. quickstart Scenario 1 pass.

---

## Phase 4: User Story 2 - <Title> (Priority: P2)

...

## Phase 5: User Story 3 - <Title> (Priority: P3)

...

---

## Phase N: Polish & Cross-Cutting Concerns

- [ ] **T-NNN** `[P]` Documentation update (`docs/domains/<domain>/charter.md` の `existing_violations` 状況更新)
- [ ] **T-NNN** Performance measurement (SC-001 / SC-002 / ...)
- [ ] **T-NNN** Security review
- [ ] **T-NNN** Run quickstart.md validation end-to-end

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3+)**: All depend on Foundational phase completion
  - User stories can then proceed in parallel (if staffed)
  - Or sequentially in priority order (P1 → P2 → P3)
- **Polish (Final Phase)**: Depends on all desired user stories being complete

### Within Each User Story

- Tests MUST be written and FAIL before implementation
- Models before services
- Services before endpoints
- Core implementation before integration
- Story complete before moving to next priority

### Parallel Opportunities

- All Setup tasks marked [P] can run in parallel
- All Foundational tasks marked [P] can run in parallel (within Phase 2)
- Once Foundational phase completes, all user stories can start in parallel (if team capacity allows)
- All tests for a user story marked [P] can run in parallel

## ID candidates (invoker が `.specify/.id-registry.json` で update する)

- bf_ids: `[BF-NNN..BF-NNN]` (from `bf_next=<N>`)
- sf_ids: `[SF-BE-NNN, SF-FE-NNN, ...]` (from `sf_be_next` / `sf_fe_next`)

## レビューチェックリスト (人間レビュー用)

- [ ] domain 帰属が正しいか
- [ ] User Story の priority (P1/P2/P3) 判定が妥当か
- [ ] 各 User Story の Independent Test が現実的か
- [ ] BF 採番範囲が必要十分か (reserved 枠の縮減検討)
- [ ] brownfield migration task と greenfield task が明確に区別されているか
