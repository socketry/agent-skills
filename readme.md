# Agent Skills

Provides the Ruby discovery and installation layer used by `agent-context`.

Run package commands through `agent-context`:

```sh
bake agent:context:install
bake agent:context:skill:list
bake agent:context:skill:install --gem provider --skill provider-workflow
bake agent:context:skill:show --gem provider --skill provider-workflow
```

The `agent:skills:*` commands are removed.

Providers may publish `context/<name>.md` documents with `type: skill` and a non-empty `description`, plus resources under `context/<name>/`. Installed names are package-prefixed. Existing `skills/<name>/SKILL.md` bundles retain their declared names. Both formats use the 64-character name and 1,024-character description limits and preserve extra metadata.

The shared ownership index at `.agents/skills/.agent-context-skills.json` records ecosystem, package, and version. Ruby installation migrates legacy ownership, stages replacements, preserves project-owned and Cargo-owned skills, and reconciles empty or removed gem providers. Only generated paths are excluded through local Git rules.

See [the packaging specification](specification.md) and [license.md](license.md).

### Developer Certificate of Origin

In order to protect users of this project, we require all contributors to comply with the [Developer Certificate of Origin](https://developercertificate.org/). This ensures that all contributions are properly licensed and attributed.

### Community Guidelines

This project is best served by a collaborative and respectful environment. Treat each other professionally, respect differing viewpoints, and engage constructively. Harassment, discrimination, or harmful behavior is not tolerated. Communicate clearly, listen actively, and support one another. If any issues arise, please inform the project maintainers.
