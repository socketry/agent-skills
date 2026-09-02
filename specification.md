# Agent Skills Packaging Specification

## 1. Purpose

This specification defines how Ruby gems can distribute reusable agent skills and how consuming projects install those skills.

The packaging convention complements the Agent Skills format: it describes transport through Ruby gems, ownership, and installation without redefining the internal semantics of a skill.

## 2. Provider Layout

A provider gem MUST place skills in a top-level `skills/` directory. Each immediate child directory represents one skill and MUST contain `SKILL.md`.

```text
package-root/
├── skills/
│   ├── first-skill/
│   │   ├── SKILL.md
│   │   └── references/
│   └── second-skill/
│       ├── SKILL.md
│       └── scripts/
├── lib/
└── package.gemspec
```

The provider MUST include the complete `skills/` tree in the packaged gem.

## 3. Skill Metadata

`SKILL.md` MUST begin with YAML frontmatter containing:

- `name`: A lowercase, hyphen-separated identifier.
- `description`: A concise explanation of when the skill applies.

The declared `name` MUST match the name of the skill directory.

Additional metadata MAY be present and is preserved as part of the installed skill.

## 4. Consumer Layout

Skills are installed into `.agents/skills/` at the consuming project root:

```text
project-root/
└── .agents/
    └── skills/
        ├── first-skill/
        ├── second-skill/
        └── .agent-skills.yaml
```

Skills are installed directly beneath `.agents/skills/` because skill names form a shared project-level namespace.

## 5. Discovery

An installer discovers provider gems by:

1. Enumerating installed Ruby gem specifications.
2. Finding top-level `skills/` directories.
3. Finding immediate child directories containing `SKILL.md`.
4. Parsing and validating required frontmatter.

Directories without `SKILL.md` are not considered skills.

## 6. Installation

Installation MUST copy the entire skill directory and preserve its internal structure.

Before modifying the destination, the installer MUST verify that:

- No other provider in the same operation supplies the same skill name.
- An existing destination is recorded as belonging to the same provider.
- A project-authored or otherwise unmanaged destination will not be overwritten.

When a provider is reinstalled, skills formerly owned by that provider but no longer present MAY be removed.

## 7. Ownership Registry

The `.agents/skills/.agent-skills.yaml` file records installed skill ownership. Its initial format is:

```yaml
version: 1
skills:
  ruby-testing:
    gem: sus
    version: 1.0.0
```

The registry MUST NOT claim ownership of pre-existing project-authored skills.

## 8. Security

Skills can contain scripts and instructions which cause agents to execute commands or modify files. Installation SHOULD therefore be an explicit project action.

Consumers SHOULD review provider skills and dependency changes before installation. Installers MUST reject ambiguous ownership rather than selecting a provider implicitly.

## 9. Version Control

Projects SHOULD exclude the generated `.agents/` directory from version control and run installation as part of setup and CI when skills are required.

Installed skills and the ownership registry MUST contain only reproducible content which can be regenerated from installed packages.
