# Agent Skills

`agent-skills` is deprecated. Skill discovery and installation are now part of [`agent-context`](https://github.com/socketry/agent-context), using the same context metadata format as [`bake-agent-context-rust`](https://github.com/socketry/bake-agent-context-rust).

## Migration

Replace `agent-skills` with `agent-context` in your Gemfile and run `bundle install`. Replace `agent:skills:*` commands with `agent:context:skill:*`:

```sh
bundle exec bake agent:context:install
bundle exec bake agent:context:skill:list
bundle exec bake agent:context:skill:show --gem provider --skill provider-workflow
bundle exec bake agent:context:skill:install --gem provider --skill provider-workflow
```

Providers should move `skills/<name>/SKILL.md` to `context/<name>.md`, add `type: skill` to its YAML front matter, and move companion resources to `context/<name>/`. Installed names become package-prefixed. Ensure `context/**/*` is included in the gem's packaged files.

```markdown
---
type: skill
description: Run the provider's workflow when setting up the package.
---

# Workflow

Follow these instructions.
```

The `agent-context` installer imports ownership from `.agents/skills/.agent-skills.yaml` into `.agents/skills/.agent-context-skills.json` and removes obsolete gem-owned skills during refresh. Project-owned skills remain protected.

See the [Agent Context documentation](https://github.com/socketry/agent-context/blob/main/guides/getting-started/readme.md), [portable specification](https://github.com/socketry/agent-context/blob/main/specification.md), and [license](license.md).

### Developer Certificate of Origin

In order to protect users of this project, we require all contributors to comply with the [Developer Certificate of Origin](https://developercertificate.org/). This ensures that all contributions are properly licensed and attributed.

### Community Guidelines

This project is best served by a collaborative and respectful environment. Treat each other professionally, respect differing viewpoints, and engage constructively. Harassment, discrimination, or harmful behavior is not tolerated. Communicate clearly, listen actively, and support one another. If any issues arise, please inform the project maintainers.
