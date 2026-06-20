# easy-query-orm

Codex skill for writing, reviewing, and debugging Java/Kotlin code that uses the
easy-query ORM.

This skill is tuned for:

- easy-query setup and proxy generation
- query, CRUD, pagination, and transactions
- `@Navigate`, `include` / `include2`, and implicit relation queries
- `whereObject`, `orderByObject`, `EasySearch`, and `selectAutoInclude`
- `savable`, native SQL, sharding, and troubleshooting

The references are distilled from easy-query source, tests, and docs, with an
emphasis on verified API names and practical routing.

## Install

Install from GitHub with the `skills` CLI:

```text
npx skills add wzszsw/easy-query-orm
```

If you prefer a manual install, clone or copy this repository into your Codex skills directory:

```text
~/.codex/skills/easy-query-orm
```

Restart Codex after a manual installation so the skill can be discovered cleanly.

## Use

Ask Codex to use the skill explicitly:

```text
Use $easy-query-orm to implement this repository query with verified easy-query APIs.
```

## Structure

```text
SKILL.md
agents/openai.yaml
references/
scripts/search_references.py
skillopt/
```

`SKILL.md` is the router. Topic-specific details live in `references/`.

## SkillOpt Assets

`skillopt/` stores local SkillOpt experiment assets for this skill, including:

- `configs/`: experiment configs used to optimize the skill
- `data/`: curated `skillqa` dataset and split files
- `notes/`: run notes and temporary analysis material

Training outputs are intentionally not tracked in git. The standard skill
installation path is still `SKILL.md` plus `references/`; `skillopt/` is only
for maintaining and reproducing optimization work on this repository.
