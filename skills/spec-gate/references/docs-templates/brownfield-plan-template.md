---
spec_id: rev-<NNN>-<DOMSHORT>-<feature-slug>
phase: plan
status: migrated
needs_human_review: true
related_principles: [<NNN>, ...]
related_cdis: [CDI-<NN>, ...]
---

# Implementation Plan: <Feature name>

**Branch**: `rev-<NNN>-<DOMSHORT>-<feature-slug>` | **Date**: <YYYY-MM-DD> | **Spec**: [spec.md](./spec.md)

> Brownfield 由来の plan。SpecKit 標準 `plan-template.md` の構造に従う。現状実装への参照は `research.md` を参照。本 file 自体は forward-looking で書く。
>
> frontmatter から `confidence` / `story_type` は **書かない** (作業メタは research.md に集約)。Phase 6 finalize 時に `status: migrated` / `needs_human_review` も除去され、SpecKit 通常 plan と区別がつかない最終形になる。

## Summary

<feature の technical approach の 1-2 段落要約>

## Technical Context

- **Language/Version**: <e.g., Node.js 22 ESM、Dart 3.8>
- **Primary Dependencies**: <list>
- **Storage**: <DB / 外部サービス>
- **Testing**: <test framework + emulator>
- **Target Platform**: <runtime + region>
- **Project Type**: <web app / mobile / API / etc>
- **Performance Goals**: <domain-specific、measurable>
- **Constraints**: <domain-specific>
- **Scale/Scope**: <想定 scale>

## Constitution Check

各 Principle に対する遵守状況。違反は `## Complexity Tracking` で justify。

- **Principle I (Secret)**: ✅ / ⚠️ / ❌ — <理由>
- **Principle II (Layering)**: ...
- **Principle III (退会 cascade、該当する場合)**: ...
- **Principle IV (監査ログ)**: ...
- **Principle V (Contract + CDI integration)**: ...
- **Principle VI (Test coverage)**: ...
- **Principle VII (Lint hookup)**: ...

### CDI 連動 (該当する場合)

- **CDI-NN (owner / consumer)**: <本 spec の体現 / 提供 / consume>

## Project Structure

### Documentation

```text
specs/rev-<NNN>-.../
├── spec.md
├── plan.md          # this file
├── research.md      # brownfield baseline + 技術選択
├── data-model.md
├── quickstart.md
├── contracts/
│   └── <api>.md
└── tasks.md
```

### Source Code

```text
<実装ディレクトリ配置>
```

**Structure Decision**: <なぜこの配置か。brownfield 移行時の旧 path → 新 path の明示も可>

## Complexity Tracking

> Constitution 違反があれば justify。なければ "なし" と記載。

| Violation | Why Needed | Simpler Alternative Rejected Because |
|---|---|---|
| (なし) | — | — |

### 既存負債 (本 spec で解消)

本 spec が解消する `existing_violations` 一覧:

- Principle <N> の <違反内容>: <解消 phase>
- ...
