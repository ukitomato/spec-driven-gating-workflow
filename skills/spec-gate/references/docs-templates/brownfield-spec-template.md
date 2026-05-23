---
spec_id: rev-<NNN>-<DOMSHORT>-<feature-slug>
phase: spec
domain: <domain>
status: migrated
needs_human_review: true
bf_ids: [BF-<NNN>, ...]
sf_ids: [SF-BE-<NNN>, SF-FE-<NNN>, ...]
related_principles: [<NNN>, ...]
related_cdis: [CDI-<NN>, ...]
linear: null
---

<!--
本 frontmatter から `confidence` / `story_type` は **書かない** (research.md に集約)。
Phase 6 finalize 時に `status: migrated` / `needs_human_review` / `bf_ids` / `sf_ids` / `phase:` も除去され、
SpecKit 通常 spec と区別がつかない最終形になる (`spec_id` も `rev-` 接頭辞が外れる)。
-->


# Feature Specification: <Feature name>

**Feature Branch**: `rev-<NNN>-<DOMSHORT>-<feature-slug>`
**Created**: <YYYY-MM-DD>
**Status**: Active
**Domain**: <domain>
**Related Principles**: <list>
**Related CDIs**: <list>

> **Brownfield 由来の spec**. forward-looking (SpecKit 標準) として書かれている。現状実装の調査 + brownfield 証跡 (file:line 等) は `research.md` を参照。本 file には実装ステート / file path / クラス名 / 3-tag marker を **書かない**。

## User Scenarios & Testing

### User Story 1 - <Brief Title> (Priority: P1) 🎯 MVP

<plain language で User Story を 1-2 段落で記述。As <role>, I want <action>, so that <value> 形式も可>

**Why this priority**: <なぜ P1 か、business value 観点>

**Independent Test**: <この story が独立に検証できる方法>

**Acceptance Scenarios**:

1. **Given** <initial state>, **When** <action>, **Then** <expected outcome>
2. **Given** ..., **When** ..., **Then** ...

---

### User Story 2 - <Title> (Priority: P2)

...

---

### Edge Cases

- <What happens when boundary condition>
- <How does system handle error scenario>
- <Race / timing / abuse / multi-actor 等の特殊ケース>

## Requirements

### Functional Requirements

#### <Category 1>

- **FR-001**: System MUST <specific capability>
- **FR-002**: System MUST <specific capability>
- ...

#### <Category 2>

- ...

### Key Entities

- **<Entity 1>**: <what it represents、key attributes WITHOUT implementation>
- **<Entity 2>**: <... relationships to other entities>

### State Transitions (該当する場合)

```
[state1] ──event──→ [state2]
```

## Success Criteria

### Measurable Outcomes

- **SC-001**: <measurable metric、technology-agnostic>
- **SC-002**: <...>

## Assumptions

- <Assumption 1>
- <Assumption 2>
- <依存する別 spec / sibling domain / 外部サービス前提>
