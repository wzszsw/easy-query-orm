# AGENTS

Repository maintenance rules for this skill:

1. Keep `SKILL.md` frontmatter `description` at or below 1024 characters after
   YAML folded-line normalization. Target under 900 characters to leave margin.
2. Keep the frontmatter `description` focused on trigger coverage only:
   what the skill does, when to use it, and the highest-value capability
   buckets. Do not list every API name there.
3. Put routing logic, behavioral rules, and maintenance guidance in the
   `SKILL.md` body. Put detailed topic material in `references/`.
4. When adding a new capability, prefer:
   `description` summary -> `SKILL.md` routing -> `references/` detail.
   Do not expand the description with long API inventories.
5. Before commit, re-measure the `SKILL.md` description length. Use this
   PowerShell snippet from repo root:

```powershell
$c = Get-Content SKILL.md -Raw
if($c -match 'description:\s*>-\s*(?<d>(?s).*?)\n---'){
  $m = $matches['d'] -replace '\r?\n\s*',' '
  $m = $m.Trim()
  $m.Length
}
```

6. If `SKILL.md` routing or positioning changes materially, check whether
   `agents/openai.yaml` still matches the public skill framing.
7. Keep symbol/package lookup source-backed. For long-tail type names, prefer
   improving `scripts/search_symbols.py` and routing to
   `references/symbol-imports.md` instead of bloating `SKILL.md` or scattering
   guessed packages across topic references.
8. Do not add extra maintenance docs beyond this file unless there is a clear
   repository-level instruction need.
