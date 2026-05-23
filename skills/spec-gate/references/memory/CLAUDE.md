## Spec-Driven Gating Workflow (Claude Code 特有)

このプロジェクトは Spec-Driven Gating Workflow を採用しています。SKILL の一覧は `/help` または `.claude/skills/spec-gate.*/SKILL.md` を参照。

### Workflow 1サイクル

```
/spec-gate.spec <description>      ─→ specs/<NNN>-<domain>-<slug>/spec.md   (drafting)
/spec-gate.plan                    ─→ plan.md                                (drafting → planning)
/spec-gate.tasks                   ─→ tasks.md                               (planning → tasking)
/spec-gate.design-gate             ─[bundle review: 3並列 reviewer]
                                     Critical=0 で                           (tasking → implementing)
/spec-gate.implement               ─→ コード + auto-chain code-gate          (→ implementing)
/spec-gate.code-gate               ─[self review: 3-5並列 + auto-fix loop]
                                     PASS で                                 (implementing → reviewing)
/spec-gate.pr-gate                 ─[adversarial review: multi-round]
                                     Critical=0 で done を許可
/spec-gate.done                    ─→ PR 提出                                (reviewing → completed)
```

### 重要原則 (Skill 内部で繰り返し参照)

- **gate 失敗時は status を進めない**。Critical 指摘を解消してから再実行する
- **AskUserQuestion gated 確定**: domain decomposition / reverse spec の domain 帰属 / Constitution Principle 採否は必ず人間承認
- **Brownfield migrate の作業中** (`/spec-gate migrate` Phase 3-5 実行中): reverse spec は `specs/rev-<NNN>-<DOM>-<slug>/` に **暫定的に** 配置し、新規 spec と区別する。**Phase 6 Finalize 完了後は `rev-` prefix を削除** して `specs/<NNN>-<DOM>-<slug>/` に統一 (`.migration-trace.md` companion で migration 履歴を識別)
- **bf_ids / sf_ids トレーサビリティ**: brownfield migrate 中は frontmatter に保持、Phase 6 Finalize 後は `.migration-trace.md` 経由でコード ↔ spec 相互参照

### Reviewer SubAgent (clean context isolation)

- `security-reviewer` — secrets / auth / injection
- `architecture-reviewer` — Constitution / Charter / ADR drift
- `po-reviewer` — User Story 価値 / SC 計測可能性
- `convention-reviewer` — naming / lint hookup
- (optional via `/spec-gate.add-reviewer`): `database-reviewer`, `a11y-reviewer`, `api-performance-reviewer`, `openapi-contract-reviewer`, `ux-reviewer`

### Brownfield specialist SubAgent

- `discovery-scanner`, `charter-drafter`, `spec-reverser`, `constitution-drafter`, `glossary-extractor`

### References

- Constitution: `.specify/memory/constitution.md`
- Domain Charter: `docs/domains/<name>/charter.md`
- Glossary: `docs/glossary.md`
- ADRs: `docs/decisions/`
