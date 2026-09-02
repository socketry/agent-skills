# Getting Started with Agent Skills

This guide explains how to discover, inspect, and install agent skills provided by Ruby gems.

## Installation

Add `agent-skills` to the consuming project:

```bash
$ bundle add agent-skills
```

List the skills available from installed gems:

```bash
$ bundle exec bake agent:skills:list
```

Install them into the project:

```bash
$ bundle exec bake agent:skills:install
```

## Source and Destination Directories

Provider gems publish skills beneath `skills/`:

```text
provider-gem/
└── skills/
    └── ruby-testing/
        ├── SKILL.md
        ├── references/
        └── scripts/
```

The consuming project receives them beneath `.agents/skills/`:

```text
consumer-project/
└── .agents/
    └── skills/
        ├── ruby-testing/
        └── .agent-skills.yaml
```

## Providing a Skill

Create a directory beneath your gem's top-level `skills/` directory. Add a `SKILL.md` file with required frontmatter:

```markdown
---
name: ruby-testing
description: Test Ruby changes with the project's configured test framework.
---

# Ruby Testing

Run the narrowest relevant test first, then run the complete suite.
```

The `name` must match the containing directory. Include the complete `skills/**/*` tree in the gemspec.

## Installation Ownership

`agent-skills` writes `.agents/skills/.agent-skills.yaml` to record which gem owns each installed skill. It will update skills owned by the same gem, but refuses to overwrite unmanaged skills or skills owned by another gem.

## Safety

Skills may contain scripts and operational instructions. Inspect skills with `bake agent:skills:list` and `bake agent:skills:show` before installation when evaluating an unfamiliar dependency.
