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

Clone or copy this repository into your Codex skills directory:

```text
~/.codex/skills/easy-query-orm
```

Restart Codex after installation so the skill can be discovered cleanly.

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
scripts/search_symbols.py
evals/
```

`SKILL.md` is the router. Topic-specific details live in `references/`.
