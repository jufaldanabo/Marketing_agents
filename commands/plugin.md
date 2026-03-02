# /plugin — Plugin Manager for Claude Code

Install and manage Claude Code plugins from GitHub — no bash scripts needed.

## Usage

```
/plugin marketplace add <github-user/repo>   → Register a plugin source
/plugin install <plugin-name>@<marketplace>  → Install a plugin
/plugin list                                  → Show marketplaces and installed commands
/plugin uninstall <plugin-name>              → Remove a plugin's commands
```

---

## Instructions for Claude

Parse the subcommand and arguments, then execute the operation using Bash.

---

### `marketplace add <github-user/repo>`

**Goal**: Download and save the marketplace catalog from a GitHub repo.

**Steps**:
1. Set `REPO` = the `<github-user/repo>` argument (e.g. `jufaldanabo/Marketing_agents`)
2. Download `.claude-plugin/marketplace.json` from that repo:
   ```bash
   mkdir -p ~/.claude/marketplaces
   curl -sL "https://raw.githubusercontent.com/$REPO/main/.claude-plugin/marketplace.json" \
     -o /tmp/_mkt_temp.json
   ```
3. Read the `"name"` field from the downloaded JSON
4. Save it:
   ```bash
   cp /tmp/_mkt_temp.json ~/.claude/marketplaces/<name>.json
   ```
5. Confirm: `✓ Marketplace '<name>' registered.`
6. List available plugins from the `plugins[]` array in the JSON

---

### `install <plugin-name>@<marketplace-name>`

**Goal**: Download all command files for the plugin into `.claude/commands/` of the current project.

**Steps**:
1. Read `~/.claude/marketplaces/<marketplace-name>.json`
2. Find the plugin where `name == <plugin-name>`
3. Get `source.repo` (e.g. `"jufaldanabo/Marketing_agents"`)
4. Download `https://raw.githubusercontent.com/<source.repo>/main/.claude-plugin/plugin.json` to get the skills list
5. For each entry in `skills[]`:
   ```bash
   mkdir -p .claude/commands
   curl -sL "https://raw.githubusercontent.com/<source.repo>/main/<skill.path>" \
     -o ".claude/commands/<skill.name>.md"
   ```
6. Show each downloaded file with `✓ <skill.name>`
7. Final message:
   ```
   ✓ Plugin '<plugin-name>' installed — <N> commands added to .claude/commands/

   Next: run /init to configure your company.
   ```

**If marketplace file not found**: Show error and suggest running `marketplace add` first.

---

### `list`

Show two sections:
1. **Marketplaces** — list files in `~/.claude/marketplaces/` (show name and plugin count)
2. **Commands installed** — list `.md` files in `.claude/commands/` of current project

```bash
echo "Marketplaces:"
ls ~/.claude/marketplaces/ 2>/dev/null | sed 's/.json//' | sed 's/^/  /'

echo ""
echo "Commands in this project:"
ls .claude/commands/*.md 2>/dev/null | xargs -I{} basename {} .md | sed 's/^/  \//'
```

---

### `uninstall <plugin-name>`

1. Read `~/.claude/marketplaces/*.json`, find the plugin by name
2. Get its `source.repo`, download its `.claude-plugin/plugin.json`
3. For each skill in `skills[]`, remove `.claude/commands/<skill.name>.md`
4. Confirm: `✓ Plugin '<plugin-name>' uninstalled.`

---

## Error handling

| Error | Message |
|---|---|
| Marketplace file not found | `Run: /plugin marketplace add <github-user/repo>` |
| Plugin not in marketplace | List available plugins in that marketplace |
| curl fails (HTTP != 200) | Show the failed URL and suggest checking the repo name |
| `.claude/commands/` not writable | Suggest `mkdir -p .claude/commands` |
