---
spec_id: rev-<NNN>-<DOMSHORT>-<feature-slug>
phase: research
status: migrated
story_type: observed
confidence: low | medium | high
generated_by: /spec-gate migrate Phase 3 (spec-reverser)
generated_at: <ISO 8601>
---

# Research: <Feature name>

**Branch**: `rev-<NNN>-<DOMSHORT>-<feature-slug>`

> **本 file は brownfield 証跡の集約場**。spec.md / plan.md / data-model.md / quickstart.md / contracts/ / tasks.md は forward-looking で書かれ、本 file は **現状実装調査 + 技術選択比較 + 既知ギャップ** に特化する。
>
> 3-tag marker (`[observed]` / `[aspiration]` / `[NOT-observed]`)、file:line 引用、git commit hash 等の brownfield 証跡は本 file でのみ使用可。

## 1. 現状実装調査 (brownfield baseline)

### 1.1 <User Story 1 の現状>

- **エントリポイント**: <path> または `<callable/HTTP の名前>`
- **flow** (順次同期実行 / 非同期 trigger / scheduled etc.):
  1. <step 1> (`<path>:<line>`)
  2. <step 2> (`<path>:<line>`)
  3. ...
- **戻り値 / 副作用**: <observed>
- **既知のギャップ** (本 spec の解消対象、Open Questions と区別):
  - <gap 1: 何が欠けているか + Principle / CDI 連携>
  - ...

### 1.2 <User Story 2 の現状>

...

### 1.N <共通基盤 / rules / index>

- DB / authz rules (`<rules-file>:<line>`): ...
- 関連 index / migration (`<index-or-migration-file>`): ...
- 既存 test (`<test-path>`) の coverage: ...

### 関連 git history (intent 抽出)

- `<commit hash> <message>` — <intent / 機能導入のきっかけ>
- `<commit hash> <message>` — ...

## 2. 技術選択 (forward-looking decisions)

### 2.1 <選択点 1: e.g., 同期 fail-fast vs event-driven>

| 選択肢 | Pros | Cons | 決定 |
|---|---|---|---|
| **Option A (推奨)** | ... | ... | ✅ |
| Option B | ... | ... | ✗ |

理由: <根拠 + 関連 Round 1-3 確定方針 / charter open question>

### 2.2 <選択点 2>

...

### 2.N idempotency 戦略 / signature 検証 / 性能戦略 (該当する場合)

...

## 3. 依存ドメイン契約

| Sibling ドメイン | 提供関数 (期待) | 入力 | 出力 | 備考 |
|---|---|---|---|---|
| <domain-a> | `<fn>` | `{...}` | `{ ok, ... }` | CDI-XX で contractualize |
| <infra-domain> (rev-<NNN>) | `<infra-fn>` | (rev-<NNN> contracts) | (同) | <infra-fn の役割> |

各 sibling 契約は対応 spec の contracts/ で正式化する。

## 4. Open Decisions (本 feature では未確定、要プロダクト判断)

- <decision 1: e.g., 保持期間の確定>
- <decision 2: e.g., 規制レビュー後の挙動>
- ...

## 5. Risk inventory

- **<risk 1>**: <発生条件 + 影響 + 対応案>
- **<risk 2>**: ...

## 6. Out of scope

- <本 spec の対象外、別 spec で扱う領域>
- ...

## 7. 用語と現状ステート (3-tag system、本 file 限定)

本 spec の各 entity / behavior の現状を 3-tag で分類。本 spec の対象外 entity / behavior は記述しない。

- `[observed]` <code / git / test 上の直接観察> (`<path>:<line>`)
- `[aspiration]` <commit message / README / charter 言及あり、未実装>
- `[NOT-observed]` <期待されるが evidence なし、Open Questions 行き>

## 8. Confidence assessment

- **総合**: low / medium / high
- 根拠: <evidence sources 列挙>
- low の場合: constitution-drafter の synthesize 入力から **除外** される (C-5-d clause)
