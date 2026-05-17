<!--
Sync Impact Report
- Version: <X.Y.Z>
- Generated/Updated: <ISO 8601>
- Generator: <human | /spec-gate.migrate Phase 4 | /speckit.constitution>
- Domains: <list>
- Tech stack: <list>
- Status: <draft | active | superseded>
- Amendment trail:
  - vX.Y.Z (ISO): <what changed>
-->

# Constitution

このプロジェクトの **不変原則 (Principles)** の SSoT。`status: active` の Principle は accepted ADR と同等の権威を持ち、違反は `architecture-reviewer` が Critical / High で指摘する。

## 改定手順

新規 Principle 追加 / 既存 Principle の変更 / 削除には以下が必要:

1. ADR (`docs/decisions/<NNNN>-...md`) で議論を記録
2. `architecture-reviewer` の owner を交えた人間レビュー
3. version を SemVer で上げる (Principle 追加 = MINOR、削除 / 後方非互換 = MAJOR、表現修正 = PATCH)
4. Amendment trail に entry を追記

## NON-NEGOTIABLE Principles

> 違反は Critical。CI で自動検証されていない場合でも、reviewer が指摘した時点で `/spec-gate.code-gate` / `/spec-gate.pr-gate` が PASS させない。

### Principle I: <name>

**Statement**: <宣言文 1-2 sentence>

**Why**: <根拠 — charter / 法令 / 過去 incident>

**Examples**:
- ✓ Good: `<path:line>` で観察
- ✗ Bad: <違反例の path:line または仮想例>

**Verification**:
- Automated: <lint rule / test / CI step があれば>
- Manual: <reviewer の checklist>

### Principle II: ...

...

## Standard Principles

> 違反は High / Medium。`should` 形式。

### Principle V: <name>

**Statement**: <should 形式>

**Why**: ...

**Examples**: ...

**Exceptions**: <例外的に違反が許容される条件があれば>

### Principle VI: ...

...

## Glossary 関連 Principle

### Principle X: Ubiquitous Language

`docs/glossary.md` 記載の用語を code / spec / UI で一貫使用する。同義異語は禁止。新規用語は glossary 追記 + reviewer 確認後に code 投入。

### Principle X+1: Multi-language consistency

(プロジェクトが多言語サポートする場合のみ)
日本語 / 英語の使い分けルール:
- Code identifiers: <英語のみ | locale 別>
- UI labels: <i18n リソース必須>
- Documentation: <英語 SSoT / 日本語訳併記>

## Domain-specific Principles

各 domain (`docs/domains/<name>/charter.md`) で固有の Principle がある場合、charter 側で記述し、本ファイルからリンクする:

- Domain `<name>` 固有 Principle: [docs/domains/<name>/charter.md#principles](../../docs/domains/<name>/charter.md#principles)

## References

- Domain Charter: [docs/domains/](../../docs/domains/)
- ADRs: [docs/decisions/](../../docs/decisions/)
- Glossary: [docs/glossary.md](../../docs/glossary.md)
