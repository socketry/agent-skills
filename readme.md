# Agent Skills

Provides tools for discovering and installing agent skills distributed by Ruby gems.

[![Development Status](https://github.com/socketry/agent-skills/workflows/Test/badge.svg)](https://github.com/socketry/agent-skills/actions?workflow=Test)

## Overview

Ruby gems can provide reusable agent workflows in a top-level `skills/` directory. `agent-skills` discovers those packages and installs them into the consuming project's `.agents/skills/` directory.

Installed skills are copied into the project so they can be used independently of the provider gem's installation path.

## Quick Start

Add the gem to your project:

``` bash
$ bundle add agent-skills
```

List available skills:

``` bash
$ bundle exec bake agent:skills:list
```

Install all available skills:

``` bash
$ bundle exec bake agent:skills:install
```

Install skills from a specific gem:

``` bash
$ bundle exec bake agent:skills:install --gem sus
```

## Providing Skills in a Gem

Create a top-level `skills/` directory containing one directory per skill:

``` text
your-gem/
├── skills/
│   └── ruby-testing/
│       ├── SKILL.md
│       ├── scripts/
│       ├── references/
│       └── assets/
├── lib/
└── your-gem.gemspec
```

Each `SKILL.md` begins with YAML frontmatter:

``` markdown
---
name: ruby-testing
description: Test Ruby projects using the project's configured test framework.
---

# Ruby Testing

Read the project instructions and run the narrowest relevant tests first.
```

The declared `name` must match its containing directory. Ensure `skills/**/*` is included in the gem's packaged files.

## Installation Safety

The installer records gem-owned skills in `.agents/skills/.agent-skills.yaml`.

  - Existing project-authored skills are never overwritten.
  - Different gems cannot install the same skill name.
  - A gem can update or remove only skills previously recorded as belonging to that gem.
  - Invalid `SKILL.md` metadata stops installation with an error.

Skills may include scripts and operational instructions. Review the skills supplied by dependencies before installing them.

The generated `.agents/` directory should be excluded from version control. Run installation during project setup and in CI when skills are required.

## Commands

``` bash
# List every gem which provides skills:
bake agent:skills:list

# List skills from one gem:
bake agent:skills:list --gem sus

# Show a skill's SKILL.md:
bake agent:skills:show --gem sus --skill ruby-testing

# Install all discovered skills:
bake agent:skills:install

# Install skills from one gem:
bake agent:skills:install --gem sus
```

## Context

This gem provides contextual documentation in `context/` for use with [`agent-context`](https://github.com/socketry/agent-context).

## Contributing

We welcome contributions. Please add tests for behavioral changes and run the test suite before opening a pull request.

### Developer Certificate of Origin

Contributors must comply with the [Developer Certificate of Origin](https://developercertificate.org/).
