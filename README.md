# Spec-Driven Gating Workflow

Hard review gates on top of Spec-Driven Development — distributed as a single gh skill.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![gh skill](https://img.shields.io/badge/gh%20skill-v2.90.0%2B-blue)](https://cli.github.com/manual/gh_skill)
[![Agent Skills](https://img.shields.io/badge/agentskills.io-compliant-green)](https://agentskills.io)
[![SemVer](https://img.shields.io/badge/SemVer-v0.1.0-orange)](CHANGELOG.md)

[GitHub Spec Kit](https://github.com/github/spec-kit) gives you `/speckit.*` commands to author specs, plans, and tasks. **Spec-Driven Gating Workflow** adds *hard gates* between those phases: adversarial reviewer SubAgents run in parallel at every phase boundary, and a feature's `status:` cannot transition forward until they return zero Critical findings.

A single `gh skill install` line adds four META subcommands (`scan` / `bootstrap` / `migrate` / `verify`). Bootstrap then generates nine project-local daily wrappers (`/<prefix>-spec`, `/<prefix>-plan`, ..., `/<prefix>-done`) that chain Spec Kit internally and enforce the gates.

<details>
<summary>Table of contents</summary>

- [Why Spec-Driven Gating?](#why-spec-driven-gating)
- [Quick Start](#quick-start)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [What you get](#what-you-get)
- [Workflow walkthrough](#workflow-walkthrough)
- [Architecture](#architecture)
- [Use cases](#use-cases)
- [Customization](#customization)
- [Compatibility](#compatibility)
- [FAQ / Troubleshooting](#faq--troubleshooting)
- [Contributing](#contributing)
- [Acknowledgments](#acknowledgments)
- [License](#license)

</details>

## Why Spec-Driven Gating?

Spec-Driven Development produces high-quality artifacts (Spec, Plan, Tasks), but their value still depends on human discipline. Under schedule pressure, review feedback gets deferred, gates are skipped, and the artifacts decay into formality.

Spec-Driven Gating introduces the **Hard Gate**: a review checkpoint where adversarial reviewer SubAgents (five to eight, running in clean context) must emit zero Critical findings before the feature's `status:` is allowed to transition to the next value. The `.specify/scripts/status-transition.sh` helper is the only mechanism allowed to write to that field, and the gate subcommands are the only mechanism allowed to invoke that helper.

| Concern                                            | Spec-Driven Development | Spec-Driven Gating Workflow |
| -------------------------------------------------- | :---------------------: | :-------------------------: |
| Spec / Plan / Tasks artifacts                      |           Yes           |             Yes             |
| Adversarial parallel review at phase boundaries    |            —            |             Yes             |
| Status lifecycle enforced by a helper script       |            —            |             Yes             |
| Optional reviewers proposed from detected stack    |            —            |             Yes             |
| Brownfield Charter / Spec reverse generation       |            —            |             Yes             |

> **Note.** This kit layers *on top of* Spec Kit; it does not replace it. The daily wrapper `/<prefix>-spec` internally chains `/speckit.specify`, `/<prefix>-plan` chains `/speckit.plan`, and so on. `specify init` is still required.

## Quick Start

From an empty directory to your first spec in five steps.

### 1. Check prerequisites

```bash
gh --version          # must be 2.90.0 or newer
uv --version          # any recent version
```

If `gh` is too old, follow the [GitHub CLI install guide](https://cli.github.com/). If you don't have `uv`:

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
uv tool install specify-cli
```

### 2. Initialize Spec Kit

```bash
mkdir my-project && cd my-project
git init
specify init
```

### 3. Install the spec-gate skill

```bash
gh skill install ukitomato/spec-driven-gating-workflow spec-gate \
  --agent claude-code --pin v0.1.0
```

For Cursor, GitHub Copilot, OpenAI Codex, Gemini CLI, or any other host sharing `.agents/skills/`, replace `--agent claude-code` with `--agent cursor`; a single install line covers all nine shared-directory hosts. To use Claude Code *and* a shared-directory host, run both lines.

### 4. Run the three META subcommands

Open your AI host (Claude Code, Cursor, ...) and run, in order:

```text
/spec-gate scan           # detect tech stack       → docs/discovery.md
/spec-gate bootstrap      # install daily wrappers  → .claude/skills/<prefix>-*/
                          #                         + .claude/agents/*.md
                          #                         + .specify/memory/constitution.draft.md
/spec-gate verify         # quality gate            → docs/verify-report.md
```

During `bootstrap`, you will choose your daily wrapper `<prefix>` (default `spec-gate`; alternatives include your project name or a short form). The kit also proposes a reviewer composition (minimum / recommended / maximum / custom) based on the tech stack detected in step `scan`.

### 5. Author your first feature

```text
/<prefix>-spec "[auth] sign-up with email and password"
```

This chains `/speckit.specify` + `/speckit.clarify`, writes `specs/001-auth-signup/spec.md` with `status: drafting`, and asks you to resolve any ambiguous requirements before continuing to plan and tasks.

For the full thirteen-step example end-to-end (about 40–70 minutes including review time), see [tutorials/greenfield-walkthrough.md](tutorials/greenfield-walkthrough.md).

## Prerequisites

- **GitHub CLI v2.90.0 or newer** — required for the `gh skill` subcommand. Install from [cli.github.com](https://cli.github.com/).
- **`uv`** — Astral's Python tool runner, used to install Spec Kit. Install with `curl -LsSf https://astral.sh/uv/install.sh | sh`.
- **Spec Kit (`specify-cli`)** — `uv tool install specify-cli`.
- **At least one supported AI coding host** — see the [Compatibility](#compatibility) section for the full matrix.
- **Git** — with at least one commit on the repo if you intend to run `/spec-gate migrate` against an existing codebase.

Claude Code reads skills from `.claude/skills/`. Nine other hosts share `.agents/skills/`. If you use Claude Code *and* one of the shared-directory hosts, run two install commands as shown in the next section.

## Installation

Choose the install line that matches your host group. Run twice if you use Claude Code together with any shared-directory host.

### Claude Code

```bash
gh skill install ukitomato/spec-driven-gating-workflow spec-gate \
  --agent claude-code --pin v0.1.0
```

### Cursor / GitHub Copilot / Codex / Gemini CLI and six more (shared `.agents/skills/`)

```bash
gh skill install ukitomato/spec-driven-gating-workflow spec-gate \
  --agent cursor --pin v0.1.0
```

A single install with any of `--agent cursor`, `--agent copilot`, `--agent codex`, `--agent gemini`, `--agent antigravity`, `--agent amp`, `--agent cline`, `--agent opencode`, or `--agent warp` deploys the skill to the shared `.agents/skills/` directory used by all nine hosts.

### Update

```bash
gh skill update ukitomato/spec-driven-gating-workflow
# or update everything at once:
gh skill update --all
```

Updates are detected by tree SHA, so an update happens only when the upstream content has actually changed. Pinned versions (`--pin v0.1.0`) are skipped automatically.

### Preview before install

```bash
gh skill preview ukitomato/spec-driven-gating-workflow spec-gate
```

### Uninstall

```bash
gh skill remove ukitomato/spec-driven-gating-workflow
```

`gh skill remove` only deletes the `spec-gate` skill itself. The project-local artifacts generated by bootstrap (`.claude/skills/<prefix>-*/`, `.claude/agents/*.md`, `.specify/memory/constitution.draft.md`, ...) are outside `gh skill`'s purview; delete them by hand when you no longer need them.

## What you get

A single `gh skill install` installs the `spec-gate` skill. From inside that skill, four META subcommands generate everything else — daily workflow wrappers, reviewer SubAgents, document templates, and helper scripts — directly into your project.

### META subcommands (in the installed skill)

| Subcommand            | Purpose                                                                                                                                       | Primary output                                                                                                  |
| --------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| `/spec-gate scan`     | Detect tech stack and framework                                                                                                               | `docs/discovery.md`                                                                                             |
| `/spec-gate bootstrap`| Install daily wrappers, reviewer SubAgents, Constitution scaffold; merge `AGENTS.md` / `CLAUDE.md`                                            | `.claude/skills/<prefix>-*/`, `.claude/agents/*.md`, `.specify/memory/constitution.draft.md`                    |
| `/spec-gate migrate`  | Brownfield 5-phase: reverse-generate Charter, Spec, Constitution, Glossary                                                                    | `docs/domains/*/charter.md`, `specs/rev-*/`, `docs/glossary.md`                                                 |
| `/spec-gate verify`   | Quality gate: structure / consistency / gap / dev-ready                                                                                       | `docs/verify-report.md` (`status: ready` / `warning` / `fail`)                                                  |

### Daily workflow wrappers (generated by bootstrap)

Bootstrap writes nine wrappers under `.claude/skills/<prefix>-*/`, where `<prefix>` is the value you chose during the bootstrap dialog (default `spec-gate`).

| Wrapper                    | Role                                | Status transition                                  |
| -------------------------- | ----------------------------------- | -------------------------------------------------- |
| `/<prefix>-spec`           | Producer                            | `→ drafting`                                       |
| `/<prefix>-plan`           | Producer                            | `drafting → planning`                              |
| `/<prefix>-tasks`          | Producer                            | `planning → tasking`                               |
| `/<prefix>-design-gate`    | **Gate**                            | `tasking → implementing` on Critical = 0           |
| `/<prefix>-implement`      | Producer (auto-chains code-gate)    | `→ implementing`                                   |
| `/<prefix>-code-gate`      | **Gate**                            | `implementing → reviewing` on MUST_FIX = 0         |
| `/<prefix>-pr-gate`        | **Gate**                            | no transition; Critical = 0 unlocks `done`         |
| `/<prefix>-done`           | Producer                            | `reviewing → completed`                            |
| `/<prefix>-add-reviewer`   | Customization                       | no transition                                      |

### SubAgents (deployed by bootstrap / migrate)

- **Five generic reviewers** (installed by bootstrap): `reviewer-base` (the shared adversary framework), `security-reviewer`, `architecture-reviewer`, `po-reviewer`, and `convention-reviewer`.
- **Three actors** (installed by bootstrap, v0.2.0): `implementer` (code-gate auto-fix loop core), `lint-agent` (JSON-structured lint runner), `test-agent` (JSON-structured test runner). Actors do **not** read `reviewer-base`; they are not reviewers.
- **Five Brownfield specialists** (installed by `scan` and `migrate`): `discovery-scanner`, `charter-drafter`, `spec-reverser`, `constitution-drafter`, `glossary-extractor`.
- **Five optional reviewers** (proposed during bootstrap based on the detected tech stack, or added later via `/<prefix>-add-reviewer --from-template`): `database-reviewer`, `a11y-reviewer`, `api-performance-reviewer`, `openapi-contract-reviewer`, `ux-reviewer`.

All 18 agents are listed in `.specify/.agents-registry.yaml` (v0.2.0). Skills validate agent presence via `gate_common::registry_assert_agent` before invocation.

All reviewer SubAgents run in clean context (no inheritance of the calling skill's conversation history). v0.2.0 replaced the "minimum 3 Critical" quota with an A-H 8-viewpoint coverage matrix (`gate_common::viewpoint_coverage_check`), and 0-cascade-evidence Critical findings are mechanically demoted to High (`gate_common::cascade_enforce`). For the full permission boundaries and the four-layer component map, see [docs/architecture.md](docs/architecture.md).

### Shared helpers (v0.2.0)

- `.specify/scripts/gate-common.sh` — atomic spec-id, cascade enforcement, viewpoint coverage, JSON verdict emit/validate, registry validation, UTF-8 grapheme-aware truncation, run-with-timeout
- `.specify/scripts/status-transition.sh --gate-transition` — verdict-validated status lifecycle transitions
- `.specify/.agents-registry.yaml` — 18-agent registry, validated before subagent invoke
- `.specify/.id-registry.json` — global namespace for brownfield `bf_ids` / `sf_ids`

## Workflow walkthrough

Every feature is one git branch. Its state lives in a `status:` field in the spec's frontmatter. The helper `.specify/scripts/status-transition.sh` is the only mechanism allowed to write that field, and the gate wrappers are the only mechanism allowed to invoke that helper.

```
drafting ──▶ planning ──▶ tasking ──[design-gate]──▶ implementing
                                                          │
                                                  [code-gate]
                                                          ▼
                                                     reviewing ──[pr-gate]──▶ completed
```

Reviewer SubAgents fire in parallel at each gate, in clean context:

```
[design-gate]   speckit.analyze  +  po-reviewer  +  architecture-reviewer
                                                                       (3 in parallel)

[code-gate]     lint  +  tests  +  convention-reviewer  +  tech-stack reviewers
                                                                       (auto-fix up to 3 iterations)

[pr-gate]       feature-scope reviewers (5)  +  system-scope reviewers (3)
                                                                       (multi-round, convergence check)
```

- **Design gate** runs `speckit.analyze` for machine consistency together with `po-reviewer` (User Story value) and `architecture-reviewer` (Constitution alignment). The status transitions only when zero Critical findings remain.
- **Code gate** runs lint, tests, `convention-reviewer`, and any tech-stack-specific reviewers. It auto-fixes up to three iterations; if the fix cascade does not converge, the gate halts and surfaces the underlying design problem.
- **PR gate** runs feature-scope reviewers (security / architecture / po, code-gate との overlap 排除済) and system-scope reviewers in multiple rounds with a convergence check at Round 4 (adjacent 2-round resolved<new rule, v0.2.0). **Pure hard gate**: `--defer-remaining` is removed; Critical=0 is required to unlock `done`. To accept current state, raise a new ADR and adjust the spec scope / Constitution Principle, then re-run pr-gate.

For the gate internals, see [docs/architecture.md](docs/architecture.md). For an end-to-end execution walkthrough, see [tutorials/greenfield-walkthrough.md](tutorials/greenfield-walkthrough.md).

## Architecture

Six design principles shape the kit:

1. **Single gh skill with subcommand dispatch.** The agentskills.io progressive disclosure pattern keeps discovery cost at roughly 100 tokens, activation at 3–5K, and execution on-demand.
2. **Distribution via `gh skill` v2.90.0+.** Provenance metadata is auto-injected, pinning is supported, and updates are detected by tree SHA.
3. **META vs. daily wrapper separation.** `/spec-gate <subcommand>` is a fixed name; `/<prefix>-<name>` is user-chosen during bootstrap.
4. **SubAgents are written project-local.** Subcommand bodies copy them into `.claude/agents/`; `gh skill` itself does not manage that directory.
5. **Status lifecycle as the hard-gate mechanism.** A status transition requires the gate verdict to succeed.
6. **Three Single Sources of Truth.** Constitution, Domain Charter, and Glossary are the only authoritative sources reviewers consult.

For the full breakdown — the four-layer component map, SubAgent permission boundaries, and non-goals — see [docs/architecture.md](docs/architecture.md).

## Use cases

Pick the path that matches the state of your repository:

| Situation                                                                              | You are        |
| -------------------------------------------------------------------------------------- | -------------- |
| Empty repo, or `git init` with zero commits                                            | **Greenfield** |
| Existing repo with code and tests, but no Constitution / Charter / Glossary            | **Brownfield** |
| Existing repo already with Constitution / Charter / Glossary                           | **Greenfield** (treat only new features) |

### Greenfield

Run `scan`, `bootstrap`, and `verify` once. Author features through `/<prefix>-spec` → `/<prefix>-plan` → `/<prefix>-tasks` → `/<prefix>-design-gate` → `/<prefix>-implement` → `/<prefix>-code-gate` → `/<prefix>-pr-gate` → `/<prefix>-done`. See [tutorials/greenfield-walkthrough.md](tutorials/greenfield-walkthrough.md) for a thirteen-step walkthrough.

### Brownfield

Run `scan` first, then `/spec-gate migrate` to reverse-generate Charter, Spec, Constitution, and Glossary from the existing codebase. The five phases (Surface Scan → Charter Reverse → Spec Reverse → Constitution Draft → Glossary Extraction) accept flags such as `--no-reverse`, `--domains <name>`, and `--resume-from <phase>`. See [tutorials/brownfield-migration.md](tutorials/brownfield-migration.md).

## Customization

- **Change the daily wrapper prefix.** Re-run `/spec-gate bootstrap --prefix mycompany --force` to regenerate every wrapper under the new prefix.
- **Add or remove reviewers.** `/<prefix>-add-reviewer <name> [--from-template <built-in>]` injects a new SubAgent and registers it in `reviewers.yml`. Built-in templates: `database-reviewer`, `a11y-reviewer`, `api-performance-reviewer`, `openapi-contract-reviewer`, `ux-reviewer`.
- **CI integration.** Embed gate verdict checks (for example `grep -q "Status: PASS"` against gate output) as required GitHub Actions checks to block merges when a gate has not run.

See [docs/customization-guide.md](docs/customization-guide.md) for prefix migration, multi-language switching, version pinning, and uninstall details. See [tutorials/custom-reviewer.md](tutorials/custom-reviewer.md) for a worked example of adding a custom reviewer.

## Compatibility

| Host                                                                                                       | `--agent` value                                                                  | Skill directory       | Status              |
| ---------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------- | --------------------- | ------------------- |
| Claude Code                                                                                                | `claude-code`                                                                    | `.claude/skills/`     | Primary             |
| Cursor                                                                                                     | `cursor`                                                                         | `.agents/skills/`     | Supported           |
| GitHub Copilot                                                                                             | `copilot`                                                                        | `.agents/skills/`     | Supported           |
| OpenAI Codex                                                                                               | `codex`                                                                          | `.agents/skills/`     | Supported           |
| Gemini CLI                                                                                                 | `gemini`                                                                         | `.agents/skills/`     | Supported           |
| Antigravity, Amp, Cline, OpenCode, Warp                                                                    | (any of `antigravity`, `amp`, `cline`, `opencode`, `warp`)                       | `.agents/skills/`     | Supported (shared)  |

Hosts that share `.agents/skills/` need only one install. Using Claude Code together with any shared-directory host requires two installs (one `--agent claude-code` and one of the shared-directory values).

> **Caveat.** Claude Code's `disable-model-invocation` frontmatter field is silently ignored by non-Claude hosts. It has no functional impact on them; it appears only as a validation warning when run through strict agentskills.io validators.

## FAQ / Troubleshooting

**Q: Does this kit replace Spec Kit?**
**A:** No. The daily wrappers chain `/speckit.*` internally. `specify init` is still required before bootstrap.

**Q: My `/<prefix>-*` commands do not appear in Claude Code.**
**A:** Run `gh skill list` and confirm that `spec-gate` is present. Then confirm that `/spec-gate bootstrap` completed successfully — it must finish writing all nine wrappers under `.claude/skills/<prefix>-*/`. Restart your AI host if it didn't pick up the new commands.

**Q: design-gate keeps producing Critical findings.**
**A:** Look for `[NEEDS CLARIFICATION]` markers in `spec.md`, confirm that the Constitution is `status: active` (not `draft`), and run `/spec-gate verify --strict` to surface structural issues that the gate cannot fix on its own.

**Q: code-gate halted with "cascade exhaustion".**
**A:** The auto-fix loop introduced a new violation with every fix. This signals a design-level problem. Step back to `/<prefix>-design-gate`, revise spec or plan, and retry.

**Q: pr-gate Round 4 failed with "convergence failure".**
**A:** Adjacent 2 rounds both had `resolved < new` (v0.2.0 mathematical definition). v0.2.0 removed `--defer-remaining` (pure hard gate). Raise a new ADR that explicitly accepts the current state, adjust the Constitution Principle / spec scope to dissolve the Critical, then re-run pr-gate (Round N+1).

**Q: Can I use this kit on its own repository (dogfooding)?**
**A:** No. This repository deliberately does not run the workflow on itself — there is a chicken-and-egg with `bootstrap`. Use `gh skill install --from-local ./skills/spec-gate` for local testing in a separate project.

**Q: Where do I report bugs or request features?**
**A:** Open an issue at <https://github.com/ukitomato/spec-driven-gating-workflow/issues>.

For deeper troubleshooting (verify-report status interpretation, brownfield migrate resume), see [docs/adoption-guide.md](docs/adoption-guide.md).

## Contributing

Issues and pull requests are welcome. The project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html); see [CHANGELOG.md](CHANGELOG.md) for the release log. The repository deliberately does not dogfood its own workflow, so new development uses standard PR review.

For local development:

```bash
gh skill install --from-local ./skills/spec-gate --agent claude-code
gh skill install anthropics/skills skill-creator
python3 .claude/skills/skill-creator/scripts/quick_validate.py skills/spec-gate/
```

## Acknowledgments

- [GitHub Spec Kit](https://github.com/github/spec-kit) — the `/speckit.*` foundation this kit composes with.
- [agentskills.io](https://agentskills.io) — the Agent Skills standard this kit complies with.
- [GitHub CLI `gh skill`](https://cli.github.com/manual/gh_skill) — the distribution layer.
- [anthropics/skills](https://github.com/anthropics/skills) — `skill-creator` is used for SKILL.md frontmatter validation during development.
- [BMAD-METHOD](https://github.com/bmad-code-org/BMAD-METHOD) — inspiration for the `document-project` Brownfield approach.
- [Quratulain-bilal/spec-kit-brownfield](https://github.com/Quratulain-bilal/spec-kit-brownfield) — reference for the five-phase Brownfield structure.

## License

Released under the [MIT License](LICENSE).
