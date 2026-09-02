# Getting Started

`agent-skills` discovers and installs reusable agent skills distributed by Ruby gems.

## Installation

```bash
$ bundle add agent-skills
$ bundle exec bake agent:skills:list
$ bundle exec bake agent:skills:install
```

## Providing Skills

Provider gems place one or more skill packages beneath a top-level `skills/` directory:

```text
your-gem/
├── skills/
│   └── ruby-testing/
│       ├── SKILL.md
│       ├── references/
│       └── scripts/
├── lib/
└── your-gem.gemspec
```

Each `SKILL.md` starts with YAML frontmatter containing a `name` and `description`. The name must match the directory.

## Installing Skills

Install every discovered skill:

```bash
$ bake agent:skills:install
```

Install from a particular gem:

```bash
$ bake agent:skills:install --gem sus
```

Installed skills are copied to `.agents/skills/`. An ownership registry prevents dependencies from overwriting project-authored skills or skills supplied by another gem.

## Inspecting Skills

```bash
$ bake agent:skills:list
$ bake agent:skills:list --gem sus
$ bake agent:skills:show --gem sus --skill ruby-testing
```

Review unfamiliar skills before installing them, especially when they include scripts.
