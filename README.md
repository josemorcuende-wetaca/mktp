# Claude Personal Marketplace

A personal Claude Code plugin marketplace — curated plugins for project context, security, and frontend work.

## Plugins

### `forge-profiles`

Plugin profile manager. Switch between sets of active plugins per work mode to keep only the relevant ones loaded and reduce context noise.

**Commands**
- `/profile-list` — list available profiles
- `/profile-create` — create a new profile from current active plugins
- `/profile-change` — switch to a different profile

Upstream: [dmedina-dev/dev-forge › forge-profiles](https://github.com/dmedina-dev/dev-forge/tree/main/plugins/forge-profiles)

### `frontend-design`

UI/UX implementation skill. Production-grade frontend design guidance that avoids the generic "AI-generated" aesthetic.

Upstream: [anthropics/claude-plugins-official › frontend-design](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/frontend-design)

### `security-guidance`

Security reminder hook. Warns about common vulnerability patterns (command injection, XSS, unsafe `eval`, pickle, etc.) when editing files.

Upstream: [anthropics/claude-plugins-official › security-guidance](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/security-guidance)

## Install

Add this marketplace, then install plugins:

```
/plugin marketplace add josemorcuende-wetaca/mktp
/plugin install forge-profiles@marketpalce
/plugin install frontend-design@marketpalce
/plugin install security-guidance@marketpalce
```

For local development, point at the working tree instead:

```
/plugin marketplace add /path/to/this/repo
```

## Structure

```
.claude-plugin/marketplace.json    manifest listing all plugins
plugins/
  forge-profiles/                  commands + skill
  frontend-design/                 skill
  security-guidance/               edit-time security hook
```
