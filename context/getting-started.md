# Getting Started

This guide explains how to migrate from the deprecated `agent-skills` gem to `agent-context`.

## Installation

Replace `agent-skills` with `agent-context` in your Gemfile, then run:

```sh
bundle install
bundle exec bake agent:context:install
```

`agent-context` includes skill discovery and installation directly. Use `agent:context:skill:list`, `agent:context:skill:show`, and `agent:context:skill:install` in place of the former `agent:skills:*` commands.

## Provider Migration

Move `skills/<name>/SKILL.md` instructions to `context/<name>.md`, add `type: skill` to the YAML front matter, and move companion resources to `context/<name>/`. Include `context/**/*` in the gem's packaged files. Installed skill names become package-prefixed, matching the Rust implementation.

```markdown
---
type: skill
description: Run the workflow when setting up this package.
---

# Workflow

Follow the setup instructions.
```

Existing installation ownership from `.agent-skills.yaml` migrates automatically. A full refresh removes stale gem-owned skills and preserves project-owned and Cargo-owned skills.

See the [Agent Context documentation](https://github.com/socketry/agent-context) for the supported commands and provider format.
