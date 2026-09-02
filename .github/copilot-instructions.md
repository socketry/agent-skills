# GitHub Copilot Instructions

## Project Instructions

Consult `agents.md` when present for project-specific guidance and installed dependency context.

Agent skills supplied by dependencies are installed into `.agents/skills/` using:

```bash
$ bundle exec bake agent:skill:install
```

Review unfamiliar skills before installing or invoking them, especially when they include scripts.
