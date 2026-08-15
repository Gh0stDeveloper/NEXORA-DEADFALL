# Contributing

NEXORA: DEADFALL is currently a private Ghost Developer / Nexora project.

## Branches

Use short-lived branches. Preferred prefixes: `feature/`, `fix/`, `chore/`, `docs/` and `agent/` for automated development work.

## Commits

Use conventional, descriptive commits such as:

- `feat: add player movement state machine`
- `fix: prevent duplicate zombie damage`
- `chore: update Godot CI version`
- `docs: define horde director rules`

## Pull requests

Keep changes scoped. Explain gameplay impact, architecture impact and validation performed. New gameplay behavior should update the GDD or relevant technical documentation when the contract changes.

## Godot conventions

- GDScript uses tabs as generated/recommended by the editor.
- Prefer typed variables and return types.
- Avoid scene-tree lookups as hidden dependencies in core simulation code.
- Do not put authoritative game rules in UI or transport classes.
- Do not commit generated `.godot/` data, builds or signing credentials.
